import { supabaseAdmin } from '../config/supabase.js';
import {
    validateTransition,
    JOB_STATES
} from '../utils/jobStateMachine.js';
import { notifyPriceRequest, notifyJobCompleted, sendPushNotification } from './fcmService.js';

class JobService {
    /**
     * Create a new job (Service Request)
     */
    async create(userId, jobData) {
        // Log input for debugging
        console.log(`📝 [JobService.create] userId=${userId}, lat=${jobData.lat}, lng=${jobData.lng}, service_id=${jobData.service_id}`);

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
            console.error('❌ [JobService.create] DB Error:', {
                code: error.code,
                message: error.message,
                details: error.details,
                hint: error.hint,
                input: { userId, lat: jobData.lat, lng: jobData.lng, service_id: jobData.service_id }
            });
            // Include DB error details in the thrown error
            const dbError = new Error(`Failed to create job: ${error.message || 'Database error'}`);
            dbError.code = error.code || 'DB_INSERT_ERROR';
            dbError.details = error.details;
            dbError.hint = error.hint;
            throw dbError;
        }

        console.log(`✅ [JobService.create] Job created successfully: ${job.id}`);

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
    /**
     * Transition: pending/searching -> accepted
     * Uses DB RPC for atomic locking
     */
    async accept(jobId, technicianId) {
        console.log(`[accept] Technician ${technicianId} attempting to accept job ${jobId}`);

        try {
            // Call Secure RPC
            const { data: result, error } = await supabaseAdmin
                .rpc('accept_job_secure', {
                    p_job_id: jobId,
                    p_technician_id: technicianId
                });

            if (error) {
                console.error(`[accept] RPC Error:`, error);
                throw new Error('Database error during acceptance');
            }

            // Handle Logic Errors returned by RPC
            if (!result.success) {
                const err = new Error(result.message || 'Failed to accept job');
                err.code = result.error_code || 'ACCEPT_FAILED';
                if (result.current_status) {
                    err.currentStatus = result.current_status;
                }
                throw err;
            }

            // Fetch the fully updated job to return formatted object
            const updatedJob = await this._getJob(jobId);

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
    async setPrice(jobId, technicianId, price, notes, paymentMethod) {
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
                metadata: { ...job.metadata, price_notes: notes, payment_method: paymentMethod },
                updated_at: new Date().toISOString()
            })
            .eq('id', jobId)
            .select()
            .single();

        if (error) throw new Error('Failed to set price');

        // Send notification to customer (in-app)
        await supabaseAdmin.from('notifications').insert({
            user_id: job.customer_id,
            type: 'price_request',
            title: 'عرض سعر جديد',
            body: `الفني أرسل عرض سعر: ${price} ريال`,
            data: { job_id: jobId, price },
            is_read: false
        });

        // Send push notification (FCM)
        await notifyPriceRequest(jobId, job.customer_id, price);

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

        // Send notification to technician (in-app)
        await supabaseAdmin.from('notifications').insert({
            user_id: job.technician_id,
            type: 'price_confirmed',
            title: 'تم قبول السعر',
            body: 'العميل وافق على السعر. يمكنك البدء بالعمل الآن!',
            data: { job_id: jobId },
            is_read: false
        });

        // Send push notification (FCM)
        await sendPushNotification(job.technician_id, {
            title: 'تم قبول السعر ✅',
            body: 'العميل وافق على السعر. يمكنك البدء بالعمل الآن!',
            data: { type: 'price_confirmed', job_id: jobId }
        });

        return updatedJob;
    }

    /**
     * Transition: in_progress -> completed
     */
    /**
     * Transition: in_progress -> pending_confirm
     */
    async requestCompletion(jobId, technicianId, { finalPrice, notes, afterPhotos } = {}) {
        const job = await this._getJob(jobId);

        if (job.technician_id !== technicianId) {
            throw new Error('Unauthorized');
        }

        validateTransition(job.status, JOB_STATES.PENDING_CONFIRM);

        const updates = {
            status: JOB_STATES.PENDING_CONFIRM,
            updated_at: new Date().toISOString()
        };

        if (finalPrice) updates.final_price = finalPrice;
        if (notes) updates.work_notes = notes;
        if (afterPhotos && Array.isArray(afterPhotos)) updates.after_photos = afterPhotos;

        const { data: updatedJob, error } = await supabaseAdmin
            .from('jobs')
            .update(updates)
            .eq('id', jobId)
            .select()
            .single();

        if (error) throw new Error('Failed to request completion');

        // Send notification to customer (in-app)
        await supabaseAdmin.from('notifications').insert({
            user_id: job.customer_id,
            type: 'completion_request',
            title: 'تأكيد إكمال الخدمة',
            body: 'الفني قام بإنهاء العمل. يرجى تأكيد استلام الخدمة لإغلاق الطلب.',
            data: { job_id: jobId },
            is_read: false
        });

        // Send push notification (FCM)
        await notifyJobCompleted(jobId, job.customer_id);

        return updatedJob;
    }

    /**
     * Transition: pending_confirm -> completed
     */
    async confirmJobCompletion(jobId, customerId) {
        const job = await this._getJob(jobId);

        if (job.customer_id !== customerId) {
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

        if (error) throw new Error('Failed to confirm completion');

        // Send notification to technician
        await supabaseAdmin.from('notifications').insert({
            user_id: job.technician_id,
            type: 'job_completed',
            title: 'تم إغلاق الطلب',
            body: 'العميل قام بتأكيد إكمال الخدمة. شكراً لك!',
            data: { job_id: jobId },
            is_read: false
        });

        // Process Commission (Deduct from Technician Wallet)
        try {
            const amount = job.final_price || job.technician_price || 0;
            if (amount > 0) {
                await supabaseAdmin.rpc('process_job_payment', {
                    job_id: jobId,
                    tech_id: job.technician_id,
                    amount: amount
                });
                console.log(`💰 Commission processed for Job ${jobId}, Amount: ${amount}`);
            }
        } catch (commError) {
            console.error('❌ Failed to process commission:', commError);
        }

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

        // 1. Insert into reviews table
        // This will fire the 'on_review_created' trigger to update user rating
        const { error: reviewError } = await supabaseAdmin
            .from('reviews')
            .insert({
                job_id: jobId,
                reviewer_id: customerId,
                reviewee_id: job.technician_id,
                rating: rating,
                comment: review
            });

        if (reviewError) {
            // Handle duplicate review or other errors
            if (reviewError.code === '23505') { // Unique violation
                throw new Error('Review already exists for this job');
            }
            throw new Error(`Failed to create review: ${reviewError.message}`);
        }

        // 2. Update Job Status
        const { data: updatedJob, error } = await supabaseAdmin
            .from('jobs')
            .update({
                status: JOB_STATES.RATED,
                rated_at: new Date().toISOString(),
                // We can still keep these for quick access if schema has them, 
                // but 'reviews' table is now the source of truth.
                // customer_rating: rating, 
                // customer_review: review,
                updated_at: new Date().toISOString()
            })
            .eq('id', jobId)
            .select()
            .single();

        if (error) throw new Error('Failed to update job status');

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
