import { supabase, supabaseAdmin } from '../config/supabase.js';

/**
 * JobService
 * Handles all business logic for the Job lifecycle.
 * Inspired by Medusa's OrderService.
 */
class JobService {

    /**
     * Create a new job (Service Request)
     */
    async create(customerId, data) {
        // 1. Validation (Business Logic)
        if (!data.service_id) throw new Error('Service ID is required');
        if (!data.lat || !data.lng) throw new Error('Location is required');

        // 2. Prepare Data
        const jobData = {
            customer_id: customerId,
            service_id: data.service_id,
            lat: data.lat,
            lng: data.lng,
            location: `POINT(${data.lng} ${data.lat})`, // PostGIS
            address_text: data.address_text,
            description: data.description,
            initial_price: data.initial_price,
            status: 'pending',
            payment_status: 'not_paid',
            search_radius: 2000, // Start with 2km
            metadata: data.metadata || {}
        };

        // 3. Insert into DB
        const { data: job, error } = await supabaseAdmin
            .from('jobs')
            .insert(jobData)
            .select()
            .single();

        if (error) throw error;

        // 4. Insert Images (if any)
        if (data.images && data.images.length > 0) {
            const imageRecords = data.images.map(url => ({
                job_id: job.id,
                image_url: url,
                media_type: 'image'
            }));

            const { error: imagesError } = await supabaseAdmin
                .from('job_images')
                .insert(imageRecords);

            if (imagesError) {
                console.error('Error inserting job images:', imagesError);
                // Don't fail the job creation, just log error
            }
        }

        return job;
    }

    /**
     * Accept a job (Technician)
     * Transition: pending/searching -> accepted
     */
    async accept(jobId, technicianId) {
        // 1. First check if the job is in an acceptable state
        const { data: existingJob, error: checkError } = await supabaseAdmin
            .from('jobs')
            .select('id, status')
            .eq('id', jobId)
            .single();

        if (checkError || !existingJob) {
            throw new Error('Job not found');
        }

        // Accept jobs that are 'pending' or 'searching'
        if (!['pending', 'searching'].includes(existingJob.status)) {
            throw new Error('Job is no longer available or already taken');
        }

        // 2. Atomic Update
        const { data: job, error } = await supabaseAdmin
            .from('jobs')
            .update({
                technician_id: technicianId,
                status: 'accepted',
                accepted_at: new Date().toISOString()
            })
            .eq('id', jobId)
            .in('status', ['pending', 'searching']) // Accept both statuses
            .select()
            .single();

        if (error || !job) {
            throw new Error('Job is no longer available or already taken');
        }

        return job;
    }

    /**
     * Set Price (Technician proposes price)
     * Transition: accepted -> price_pending
     */
    async setPrice(jobId, technicianId, price, notes) {
        if (price <= 0) throw new Error('Price must be positive');

        const { data: job, error } = await supabase
            .from('jobs')
            .update({
                technician_price: price,
                price_notes: notes,
                status: 'price_pending'
            })
            .eq('id', jobId)
            .eq('technician_id', technicianId)
            .eq('status', 'accepted')
            .select()
            .single();

        if (error || !job) throw new Error('Job not found or invalid status');

        return job;
    }

    /**
     * Confirm Price (Customer)
     * Transition: price_pending -> in_progress
     */
    async confirmPrice(jobId, customerId) {
        const { data: job, error } = await supabase
            .from('jobs')
            .update({
                status: 'in_progress',
                price_confirmed_at: new Date().toISOString()
            })
            .eq('id', jobId)
            .eq('customer_id', customerId)
            .eq('status', 'price_pending')
            .select()
            .single();

        if (error || !job) throw new Error('Job not found or invalid status');

        return job;
    }

    /**
     * Complete Job (Technician)
     * Transition: in_progress -> completed
     * Triggers: Payment Processing
     */
    async complete(jobId, technicianId) {
        // 1. Verify Job
        const { data: job, error: fetchError } = await supabase
            .from('jobs')
            .select('*')
            .eq('id', jobId)
            .eq('technician_id', technicianId)
            .single();

        if (fetchError || !job) throw new Error('Job not found');
        if (job.status !== 'in_progress') throw new Error('Job is not in progress');

        // 2. Process Payment (Atomic Transaction via RPC)
        // This ensures money moves only if job completes
        const amount = job.technician_price || job.initial_price;

        const { data: paymentResult, error: rpcError } = await supabaseAdmin
            .rpc('process_job_payment', {
                p_job_id: jobId,
                p_amount: amount
            });

        if (rpcError) throw rpcError;
        if (!paymentResult.success) throw new Error(paymentResult.message);

        // 3. Update Status
        const { data: updatedJob, error: updateError } = await supabase
            .from('jobs')
            .update({
                status: 'completed',
                completed_at: new Date().toISOString()
            })
            .eq('id', jobId)
            .select()
            .single();

        if (updateError) throw updateError;

        return updatedJob;
    }

    /**
     * Cancel Job
     * Transition: * -> cancelled
     */
    async cancel(jobId, userId, reason) {
        // 1. Get Job
        const { data: job, error: fetchError } = await supabase
            .from('jobs')
            .select('*')
            .eq('id', jobId)
            .single();

        if (fetchError || !job) throw new Error('Job not found');

        // 2. Permission Check
        if (job.customer_id !== userId && job.technician_id !== userId) {
            throw new Error('Unauthorized');
        }

        if (job.status === 'completed') throw new Error('Cannot cancel completed job');

        // 3. Update Status
        const { data: updatedJob, error } = await supabase
            .from('jobs')
            .update({
                status: 'cancelled',
                cancelled_by: userId,
                cancel_reason: reason,
                cancelled_at: new Date().toISOString()
            })
            .eq('id', jobId)
            .select()
            .single();

        if (error) throw error;

        return updatedJob;
    }

    /**
     * Rate Job (Customer)
     */
    async rate(jobId, customerId, rating, review) {
        if (rating < 1 || rating > 5) throw new Error('Rating must be between 1 and 5');

        // 1. Verify Job
        const { data: job, error: fetchError } = await supabase
            .from('jobs')
            .select('*')
            .eq('id', jobId)
            .eq('customer_id', customerId)
            .eq('status', 'completed')
            .single();

        if (fetchError || !job) throw new Error('Job not found or not completed');
        if (job.customer_rating) throw new Error('Job already rated');

        // 2. Update Job
        const { data: updatedJob, error: updateError } = await supabase
            .from('jobs')
            .update({
                customer_rating: rating,
                customer_review: review,
                rated_at: new Date().toISOString()
            })
            .eq('id', jobId)
            .select()
            .single();

        if (updateError) throw updateError;

        return updatedJob;
    }
}

export const jobService = new JobService();
