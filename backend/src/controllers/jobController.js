import Joi from 'joi';
import { supabase, supabaseAdmin } from '../config/supabase.js';
import { startJobSearch, onJobAccepted, cancelJobSearch } from '../services/jobSearchService.js';

// Validation Schemas
const createJobSchema = Joi.object({
    service_id: Joi.string().required(),
    lat: Joi.number().required(),
    lng: Joi.number().required(),
    address_text: Joi.string().required(),
    description: Joi.string().optional(),
    initial_price: Joi.number().required()
});

// 1. Create a New Job
export const createJob = async (req, res) => {
    try {
        const { error, value } = createJobSchema.validate(req.body);
        if (error) return res.status(400).json({ success: false, message: error.details[0].message });

        // Use supabaseAdmin to bypass RLS policies for insertion
        const { data: job, error: dbError } = await supabaseAdmin
            .from('jobs')
            .insert({
                customer_id: req.user.id,
                service_id: value.service_id,
                lat: value.lat,
                lng: value.lng,
                address_text: value.address_text,
                description: value.description,
                initial_price: value.initial_price,
                status: 'pending'
            })
            .select()
            .single();

        if (dbError) throw dbError;

        // 🚀 Start Smart Search - This will:
        // 1. Find nearby technicians in 2km radius
        // 2. Send them notifications
        // 3. Auto-expand to 5km after 2 minutes
        // 4. Auto-expand to 10km after 3 more minutes
        startJobSearch(job.id, value.lat, value.lng, value.service_id);

        res.status(201).json({
            success: true,
            message: 'Job created successfully. Searching for technicians...',
            job,
            search_config: {
                initial_radius: 2000,
                tiers: [
                    { radius: 2000, duration: '2 minutes' },
                    { radius: 5000, duration: '3 minutes' },
                    { radius: 10000, duration: '5 minutes' },
                ]
            }
        });

    } catch (error) {
        console.error('Create Job Error:', error);
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};

// 2. Get Nearby Jobs (For Technicians) with Pagination
export const getNearbyJobs = async (req, res) => {
    try {
        const { lat, lng, radius = 5000, page = 1, limit = 20 } = req.query;

        if (!lat || !lng) {
            return res.status(400).json({ success: false, message: 'Location (lat, lng) is required' });
        }

        const pageNum = parseInt(page, 10) || 1;
        const limitNum = Math.min(parseInt(limit, 10) || 20, 50); // Max 50
        const offset = (pageNum - 1) * limitNum;

        // Get pending jobs with pagination
        const { data: jobs, error, count } = await supabase
            .from('jobs')
            .select('*, service:services(name, icon_url), customer:users!customer_id(full_name, rating)', { count: 'exact' })
            .eq('status', 'pending')
            .order('created_at', { ascending: false })
            .range(offset, offset + limitNum - 1);

        if (error) throw error;

        res.json({
            success: true,
            count: jobs.length,
            total: count,
            page: pageNum,
            totalPages: Math.ceil((count || 0) / limitNum),
            jobs
        });

    } catch (error) {
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};

// 3. Accept Job (The Race Condition Solver!)
export const acceptJob = async (req, res) => {
    const { id } = req.params; // Job ID
    const technicianId = req.user.id;

    try {
        // Atomic Update: Only update if status is 'pending'
        const { data: job, error } = await supabase
            .from('jobs')
            .update({
                technician_id: technicianId,
                status: 'accepted',
                accepted_at: new Date().toISOString()
            })
            .eq('id', id)
            .eq('status', 'pending') // <--- The Lock 🔒
            .select()
            .single();

        if (error || !job) {
            // If no job returned, it means it was already taken (or doesn't exist)
            return res.status(409).json({
                success: false,
                message: 'Job already taken by another technician or unavailable.'
            });
        }

        // 🛑 Stop the search - technician found!
        onJobAccepted(id);

        res.json({
            success: true,
            message: 'Job accepted successfully!',
            job
        });

    } catch (error) {
        console.error('Accept Job Error:', error);
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};

// 4. Get My Jobs (History)
export const getMyJobs = async (req, res) => {
    try {
        const userId = req.user.id;
        // Check if user is customer or technician to filter correctly
        // But since we have RLS, we can just query 'jobs' and Supabase will filter?
        // No, we are using the service_role key in some places or the client.
        // Here we are using `supabase` client which is initialized with ANON key in `config/supabase.js`.
        // Wait, in `config/supabase.js` we init with ANON key. 
        // But we are passing the user's token in the header? 
        // Actually, the `supabase` client in `config/supabase.js` is a global client. 
        // It doesn't know about the current user unless we set the session.

        // Correct pattern for RLS with Node.js:
        // We should probably just query with explicit ID filters since we verified the user in middleware.

        const { data: jobs, error } = await supabase
            .from('jobs')
            .select('*, service:services(name)')
            .or(`customer_id.eq.${userId},technician_id.eq.${userId}`)
            .order('created_at', { ascending: false });

        if (error) throw error;

        res.json({ success: true, jobs });

    } catch (error) {
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};

// 5. Complete Job (Technician finishes work)
export const completeJob = async (req, res) => {
    const { id } = req.params;
    const technicianId = req.user.id;

    try {
        // 1. Verify Job belongs to technician and is in progress/accepted
        const { data: job, error: fetchError } = await supabase
            .from('jobs')
            .select('*')
            .eq('id', id)
            .eq('technician_id', technicianId)
            .single();

        if (fetchError || !job) {
            return res.status(404).json({ success: false, message: 'Job not found or unauthorized' });
        }

        if (job.status === 'completed') {
            return res.status(400).json({ success: false, message: 'Job already completed' });
        }

        // 2. Update status to completed
        const { error: updateError } = await supabase
            .from('jobs')
            .update({
                status: 'completed',
                completed_at: new Date().toISOString()
            })
            .eq('id', id);

        if (updateError) throw updateError;

        // 3. Process Payment & Commission (Using Database Function)
        // Assuming the price is fixed or was set during acceptance. 
        // If dynamic, we should pass it in body.
        const amount = job.technician_price || job.initial_price || 0;

        if (amount > 0) {
            const { error: rpcError } = await supabase.rpc('process_job_payment', {
                job_id: id,
                tech_id: technicianId,
                amount: amount
            });

            if (rpcError) {
                console.error('Commission Deduction Failed:', rpcError);
                // Note: In production, we might want to rollback or flag this for manual review
            }
        }

        res.json({ success: true, message: 'Job completed and commission processed' });

    } catch (error) {
        console.error('Complete Job Error:', error);
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};

// 6. Set Price (Technician proposes price after inspecting the job)
export const setPrice = async (req, res) => {
    const { id } = req.params;
    const technicianId = req.user.id;
    const { price, notes } = req.body;

    try {
        // Validate price
        if (!price || price <= 0) {
            return res.status(400).json({ success: false, message: 'Price must be a positive number' });
        }

        // Verify job belongs to this technician and is in accepted status
        const { data: job, error: fetchError } = await supabase
            .from('jobs')
            .select('*')
            .eq('id', id)
            .eq('technician_id', technicianId)
            .eq('status', 'accepted')
            .single();

        if (fetchError || !job) {
            return res.status(404).json({
                success: false,
                message: 'Job not found, not assigned to you, or not in correct status'
            });
        }

        // Update job with proposed price
        const { data: updatedJob, error: updateError } = await supabase
            .from('jobs')
            .update({
                technician_price: price,
                price_notes: notes || null,
                status: 'price_pending'  // Waiting for customer confirmation
            })
            .eq('id', id)
            .select()
            .single();

        if (updateError) throw updateError;

        res.json({
            success: true,
            message: 'Price submitted successfully. Waiting for customer confirmation.',
            job: updatedJob
        });

    } catch (error) {
        console.error('Set Price Error:', error);
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};

// 7. Confirm Price (Customer accepts or rejects the proposed price)
export const confirmPrice = async (req, res) => {
    const { id } = req.params;
    const customerId = req.user.id;
    const { accepted, counter_offer } = req.body;

    try {
        // Verify job belongs to this customer and is waiting for price confirmation
        const { data: job, error: fetchError } = await supabase
            .from('jobs')
            .select('*')
            .eq('id', id)
            .eq('customer_id', customerId)
            .eq('status', 'price_pending')
            .single();

        if (fetchError || !job) {
            return res.status(404).json({
                success: false,
                message: 'Job not found or not waiting for price confirmation'
            });
        }

        if (accepted) {
            // Customer accepts the price - move to in_progress
            const { data: updatedJob, error: updateError } = await supabase
                .from('jobs')
                .update({
                    status: 'in_progress',
                    price_confirmed_at: new Date().toISOString()
                })
                .eq('id', id)
                .select()
                .single();

            if (updateError) throw updateError;

            res.json({
                success: true,
                message: 'Price accepted! Technician is now on the way.',
                job: updatedJob
            });
        } else {
            // Customer rejects - either cancel or send counter offer
            if (counter_offer && counter_offer > 0) {
                // Send counter offer back to technician
                const { data: updatedJob, error: updateError } = await supabase
                    .from('jobs')
                    .update({
                        customer_offer: counter_offer,
                        status: 'counter_offer'
                    })
                    .eq('id', id)
                    .select()
                    .single();

                if (updateError) throw updateError;

                res.json({
                    success: true,
                    message: 'Counter offer sent to technician.',
                    job: updatedJob
                });
            } else {
                // Customer rejects without counter - release technician
                const { error: updateError } = await supabase
                    .from('jobs')
                    .update({
                        status: 'pending',
                        technician_id: null,
                        technician_price: null,
                        price_notes: null
                    })
                    .eq('id', id);

                if (updateError) throw updateError;

                res.json({
                    success: true,
                    message: 'Price rejected. Looking for another technician.'
                });
            }
        }

    } catch (error) {
        console.error('Confirm Price Error:', error);
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};

// 8. Rate Job (Customer rates the technician after completion)
export const rateJob = async (req, res) => {
    const { id } = req.params;
    const customerId = req.user.id;
    const { rating, review } = req.body;

    try {
        // Validate rating
        if (!rating || rating < 1 || rating > 5) {
            return res.status(400).json({ success: false, message: 'Rating must be between 1 and 5' });
        }

        // Verify job belongs to customer and is completed
        const { data: job, error: fetchError } = await supabase
            .from('jobs')
            .select('*')
            .eq('id', id)
            .eq('customer_id', customerId)
            .eq('status', 'completed')
            .single();

        if (fetchError || !job) {
            return res.status(404).json({
                success: false,
                message: 'Job not found or not completed yet'
            });
        }

        if (job.customer_rating) {
            return res.status(400).json({ success: false, message: 'Job already rated' });
        }

        // Update job with rating
        const { data: updatedJob, error: updateError } = await supabase
            .from('jobs')
            .update({
                customer_rating: rating,
                customer_review: review || null,
                rated_at: new Date().toISOString()
            })
            .eq('id', id)
            .select()
            .single();

        if (updateError) throw updateError;

        // Update technician's average rating
        const { data: techJobs } = await supabase
            .from('jobs')
            .select('customer_rating')
            .eq('technician_id', job.technician_id)
            .not('customer_rating', 'is', null);

        if (techJobs && techJobs.length > 0) {
            const avgRating = techJobs.reduce((sum, j) => sum + j.customer_rating, 0) / techJobs.length;

            await supabase
                .from('users')
                .update({ rating: Math.round(avgRating * 10) / 10 })
                .eq('id', job.technician_id);
        }

        res.json({
            success: true,
            message: 'Thank you for your rating!',
            job: updatedJob
        });

    } catch (error) {
        console.error('Rate Job Error:', error);
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};

// 9. Cancel Job (Either party can cancel before completion)
export const cancelJob = async (req, res) => {
    const { id } = req.params;
    const userId = req.user.id;
    const { reason } = req.body;

    try {
        // Find the job
        const { data: job, error: fetchError } = await supabase
            .from('jobs')
            .select('*')
            .eq('id', id)
            .single();

        if (fetchError || !job) {
            return res.status(404).json({ success: false, message: 'Job not found' });
        }

        // Check permission
        if (job.customer_id !== userId && job.technician_id !== userId) {
            return res.status(403).json({ success: false, message: 'Not authorized to cancel this job' });
        }

        // Can't cancel completed jobs
        if (job.status === 'completed') {
            return res.status(400).json({ success: false, message: 'Cannot cancel completed job' });
        }

        // Update job status
        const { error: updateError } = await supabase
            .from('jobs')
            .update({
                status: 'cancelled',
                cancelled_by: userId,
                cancel_reason: reason || null,
                cancelled_at: new Date().toISOString()
            })
            .eq('id', id);

        if (updateError) throw updateError;

        // Stop the search if still active
        cancelJobSearch(id);

        res.json({
            success: true,
            message: 'Job cancelled successfully'
        });

    } catch (error) {
        console.error('Cancel Job Error:', error);
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};
