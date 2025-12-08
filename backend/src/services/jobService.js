import { supabaseAdmin } from '../config/supabase.js';
import {
    validateTransition,
    JOB_STATES
} from '../utils/jobStateMachine.js';

class JobService {
    /**
     * Create a new job (Service Request)
     */
    async create(userId, jobData) {
        // 1. Prepare Data
        const jobToInsert = {
            customer_id: userId,
            service_id: jobData.service_id,
            lat: jobData.lat,
            lng: jobData.lng,
            location: `SRID=4326;POINT(${jobData.lng} ${jobData.lat})`, // PostGIS
            address_text: jobData.address_text,
            description: jobData.description,
            initial_price: jobData.initial_price,
            status: JOB_STATES.PENDING,
            search_radius: 5000, // 5km initial radius
            metadata: jobData.metadata || {}
        };

        // 2. Insert into DB
        const { data: job, error } = await supabaseAdmin
            .from('jobs')
            .insert(jobToInsert)
            .select()
            .single();

        if (error) {
            console.error('Create Job DB Error:', error);
            throw new Error('Failed to create job');
        }

        // 3. Insert Images (if any)
        if (jobData.images && jobData.images.length > 0) {
            const imageRecords = jobData.images.map(url => ({
                job_id: job.id,
                image_url: url,
                media_type: 'image'
            }));

            const { error: imagesError } = await supabaseAdmin
                .from('job_images')
                .insert(imageRecords);

            if (imagesError) {
                console.error('Error inserting job images:', imagesError);
            }
        }

        return job;
    }

    /**
     * Transition: pending/searching -> accepted
     */
    async accept(jobId, technicianId) {
        console.log(`[accept] Technician ${technicianId} attempting to accept job ${jobId}`);

        try {
            // Step 1: Fetch current job state
            const currentJob = await this._getJob(jobId);

            // Step 2: Validate current status
            validateTransition(currentJob.status, JOB_STATES.ACCEPTED);

            // Step 3: Atomic update with condition
            const { data: updatedJob, error: updateError } = await supabaseAdmin
                .from('jobs')
                .update({
                    technician_id: technicianId,
                    status: JOB_STATES.ACCEPTED,
                    accepted_at: new Date().toISOString(),
                    updated_at: new Date().toISOString()
                })
                .eq('id', jobId)
                .in('status', [JOB_STATES.PENDING, JOB_STATES.SEARCHING, JOB_STATES.NO_TECHNICIAN]) // Atomic guard
                .select()
                .single();

            if (updateError) {
                console.error(`[accept] Update error:`, updateError);
                const err = new Error('Failed to accept job. It may have been accepted by another technician.');
                err.code = 'ACCEPT_FAILED';
                throw err;
            }

            if (!updatedJob) {
                const err = new Error('Job was accepted by another technician');
                err.code = 'JOB_ALREADY_ACCEPTED';
                throw err;
            }

            console.log(`✅ [accept] Job ${jobId} successfully accepted by technician ${technicianId}`);
            return updatedJob;

        } catch (error) {
            console.error(`❌ [accept] Error:`, error);
            throw error;
        }
    }

    /**
     * Transition: accepted -> price_pending
     */
    async setPrice(jobId, technicianId, price, notes) {
        if (price <= 0) throw new Error('Price must be positive');

        const job = await this._getJob(jobId);

        if (job.technician_id !== technicianId) {
            throw new Error('Unauthorized');
        }

        validateTransition(job.status, JOB_STATES.PRICE_PENDING);

        const { data: updatedJob, error } = await supabaseAdmin
            .from('jobs')
            .update({
                technician_price: price,
                status: JOB_STATES.PRICE_PENDING,
                metadata: { ...job.metadata, price_notes: notes },
                updated_at: new Date().toISOString()
            })
            .eq('id', jobId)
            .select()
            .single();

        if (error) throw new Error('Failed to set price');

        // Send notification to customer
        await supabaseAdmin.from('notifications').insert({
            user_id: job.customer_id,
            type: 'price_request',
            title: 'عرض سعر جديد',
            body: `الفني أرسل عرض سعر: ${price} ريال`,
            data: { job_id: jobId, price },
            is_read: false
        });

        return updatedJob;
    }

    /**
     * Transition: price_pending -> in_progress
     */
    async confirmPrice(jobId, customerId) {
        const job = await this._getJob(jobId);

        if (job.customer_id !== customerId) {
            throw new Error('Unauthorized');
        }

        validateTransition(job.status, JOB_STATES.IN_PROGRESS);

        const { data: updatedJob, error } = await supabaseAdmin
            .from('jobs')
            .update({
                final_price: job.technician_price,
                status: JOB_STATES.IN_PROGRESS,
                price_confirmed_at: new Date().toISOString(),
                updated_at: new Date().toISOString()
            })
            .eq('id', jobId)
            .select()
            .single();

        if (error) throw new Error('Failed to confirm price');

        // Send notification to technician
        await supabaseAdmin.from('notifications').insert({
            user_id: job.technician_id,
            type: 'price_confirmed',
            title: 'تم قبول السعر',
            body: 'العميل وافق على السعر. يمكنك البدء بالعمل الآن!',
            data: { job_id: jobId },
            is_read: false
        });

        return updatedJob;
    }

    /**
     * Transition: in_progress -> completed
     */
    async complete(jobId, technicianId) {
        const job = await this._getJob(jobId);

        if (job.technician_id !== technicianId) {
            throw new Error('Unauthorized');
        }

        validateTransition(job.status, JOB_STATES.COMPLETED);

        const { data: updatedJob, error } = await supabaseAdmin
            .from('jobs')
            .update({
                status: JOB_STATES.COMPLETED,
                completed_at: new Date().toISOString(),
                updated_at: new Date().toISOString()
            })
            .eq('id', jobId)
            .select()
            .single();

        if (error) throw new Error('Failed to complete job');

        // Send notification to customer
        await supabaseAdmin.from('notifications').insert({
            user_id: job.customer_id,
            type: 'job_completed',
            title: 'تم إنهاء الخدمة',
            body: 'الفني أنهى العمل. يرجى تقييم الخدمة.',
            data: { job_id: jobId },
            is_read: false
        });

        return updatedJob;
    }

    /**
     * Transition: completed -> rated
     */
    async rate(jobId, customerId, rating, review) {
        const job = await this._getJob(jobId);

        if (job.customer_id !== customerId) {
            throw new Error('Unauthorized');
        }

        validateTransition(job.status, JOB_STATES.RATED);

        const { data: updatedJob, error } = await supabaseAdmin
            .from('jobs')
            .update({
                status: JOB_STATES.RATED,
                rated_at: new Date().toISOString(),
                customer_rating: rating,
                customer_review: review,
                updated_at: new Date().toISOString()
            })
            .eq('id', jobId)
            .select()
            .single();

        if (error) throw new Error('Failed to rate job');

        // Update technician's average rating
        if (job.technician_id) {
            // Get all ratings for this technician
            const { data: techJobs } = await supabaseAdmin
                .from('jobs')
                .select('customer_rating')
                .eq('technician_id', job.technician_id)
                .not('customer_rating', 'is', null);

            if (techJobs && techJobs.length > 0) {
                const totalRating = techJobs.reduce((sum, j) => sum + (j.customer_rating || 0), 0);
                const avgRating = totalRating / techJobs.length;

                await supabaseAdmin
                    .from('users')
                    .update({
                        rating: Math.round(avgRating * 100) / 100,
                        total_reviews: techJobs.length,
                        updated_at: new Date().toISOString()
                    })
                    .eq('id', job.technician_id);
            }
        }

        return updatedJob;
    }

    /**
     * Transition: * -> cancelled
     */
    async cancel(jobId, userId, reason) {
        const job = await this._getJob(jobId);

        if (job.customer_id !== userId && job.technician_id !== userId) {
            throw new Error('Unauthorized');
        }

        validateTransition(job.status, JOB_STATES.CANCELLED);

        const { data: updatedJob, error } = await supabaseAdmin
            .from('jobs')
            .update({
                status: JOB_STATES.CANCELLED,
                cancelled_at: new Date().toISOString(),
                metadata: { ...job.metadata, cancellation_reason: reason, cancelled_by: userId },
                updated_at: new Date().toISOString()
            })
            .eq('id', jobId)
            .select()
            .single();

        if (error) throw new Error('Failed to cancel job');
        return updatedJob;
    }

    // Helper: Get Job or Throw
    async _getJob(jobId) {
        const { data: job, error } = await supabaseAdmin
            .from('jobs')
            .select('*')
            .eq('id', jobId)
            .single();

        if (error || !job) {
            const err = new Error('Job not found');
            err.code = 'JOB_NOT_FOUND';
            throw err;
        }

        return job;
    }
}

export const jobService = new JobService();
