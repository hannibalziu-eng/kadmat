import Joi from 'joi';
import { supabase } from '../config/supabase.js';
import { jobService } from '../services/jobService.js';
import { startJobSearch, onJobAccepted, cancelJobSearch } from '../services/jobSearchService.js';

// Validation Schemas
const createJobSchema = Joi.object({
    service_id: Joi.string().required(),
    lat: Joi.number().required(),
    lng: Joi.number().required(),
    address_text: Joi.string().required(),
    description: Joi.string().optional(),
    initial_price: Joi.number().required(),
    metadata: Joi.object().optional(),
    images: Joi.array().items(Joi.string()).optional()
});

// 1. Create a New Job
export const createJob = async (req, res) => {
    try {
        const { error, value } = createJobSchema.validate(req.body);
        if (error) return res.status(400).json({ success: false, message: error.details[0].message });

        const job = await jobService.create(req.user.id, value);

        // Start Smart Search
        startJobSearch(job.id, value.lat, value.lng, value.service_id);

        res.status(201).json({
            success: true,
            message: 'Job created successfully',
            job
        });
    } catch (error) {
        console.error('Create Job Error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

// 2. Get Nearby Jobs (Query)
export const getNearbyJobs = async (req, res) => {
    try {
        const { lat, lng, radius = 5000, page = 1, limit = 20 } = req.query;

        if (!lat || !lng) {
            return res.status(400).json({ success: false, message: 'Location (lat, lng) is required' });
        }

        const pageNum = parseInt(page, 10) || 1;
        const limitNum = Math.min(parseInt(limit, 10) || 20, 50);
        const offset = (pageNum - 1) * limitNum;

        const twelveHoursAgo = new Date(Date.now() - 12 * 60 * 60 * 1000).toISOString();

        const { data: jobs, error, count } = await supabase
            .from('jobs')
            .select('*, service:services(name, icon_url), customer:users!customer_id(full_name, rating)', { count: 'exact' })
            .eq('status', 'pending')
            .gt('created_at', twelveHoursAgo)
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
        res.status(500).json({ success: false, message: error.message });
    }
};

// 3. Accept Job
export const acceptJob = async (req, res) => {
    try {
        const job = await jobService.accept(req.params.id, req.user.id);

        onJobAccepted(job.id);

        res.json({ success: true, message: 'Job accepted', job });
    } catch (error) {
        res.status(400).json({ success: false, message: error.message });
    }
};

// 4. Get My Jobs
export const getMyJobs = async (req, res) => {
    try {
        const { data: jobs, error } = await supabase
            .from('jobs')
            .select('*, service:services(name)')
            .or(`customer_id.eq.${req.user.id},technician_id.eq.${req.user.id}`)
            .neq('status', 'cancelled')
            .order('created_at', { ascending: false });

        if (error) throw error;

        res.json({ success: true, jobs });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// 5. Complete Job
export const completeJob = async (req, res) => {
    try {
        const job = await jobService.complete(req.params.id, req.user.id);
        res.json({ success: true, message: 'Job completed', job });
    } catch (error) {
        res.status(400).json({ success: false, message: error.message });
    }
};

// 6. Set Price
export const setPrice = async (req, res) => {
    try {
        const { price, notes } = req.body;
        const job = await jobService.setPrice(req.params.id, req.user.id, price, notes);
        res.json({ success: true, message: 'Price submitted', job });
    } catch (error) {
        res.status(400).json({ success: false, message: error.message });
    }
};

// 7. Confirm Price
export const confirmPrice = async (req, res) => {
    try {
        const job = await jobService.confirmPrice(req.params.id, req.user.id);
        res.json({ success: true, message: 'Price confirmed', job });
    } catch (error) {
        res.status(400).json({ success: false, message: error.message });
    }
};

// 8. Rate Job
export const rateJob = async (req, res) => {
    try {
        const { rating, review } = req.body;
        const job = await jobService.rate(req.params.id, req.user.id, rating, review);
        res.json({ success: true, message: 'Rating submitted', job });
    } catch (error) {
        res.status(400).json({ success: false, message: error.message });
    }
};

// 9. Cancel Job
export const cancelJob = async (req, res) => {
    try {
        const { reason } = req.body;
        const job = await jobService.cancel(req.params.id, req.user.id, reason);

        cancelJobSearch(job.id);

        res.json({ success: true, message: 'Job cancelled', job });
    } catch (error) {
        res.status(400).json({ success: false, message: error.message });
    }
};
