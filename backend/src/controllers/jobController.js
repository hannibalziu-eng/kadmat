import Joi from 'joi';
import { supabase } from '../config/supabase.js';
import { jobService } from '../services/jobService.js';
import { startJobSearch, onJobAccepted, cancelJobSearch } from '../services/jobSearchService.js';
import { responseFormatter, ERROR_CODES, HTTP_STATUS } from '../utils/responseFormatter.js';

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
        if (error) {
            const { response, statusCode } = responseFormatter.error(
                ERROR_CODES.VALIDATION_FAILED,
                error.details[0].message
            );
            return res.status(statusCode).json(response);
        }

        const job = await jobService.create(req.user.id, value);

        // Start Smart Search
        startJobSearch(job.id, value.lat, value.lng, value.service_id);

        return res.status(HTTP_STATUS.CREATED).json(
            responseFormatter.success(job, 'Job created successfully')
        );
    } catch (error) {
        console.error('Create Job Error:', error);
        const { response, statusCode } = responseFormatter.error(
            ERROR_CODES.DATABASE_ERROR,
            error.message
        );
        return res.status(statusCode).json(response);
    }
};

// 2. Get Nearby Jobs (Query)
export const getNearbyJobs = async (req, res) => {
    try {
        const { lat, lng, radius = 5000, page = 1, limit = 20 } = req.query;

        if (!lat || !lng) {
            const { response, statusCode } = responseFormatter.error(
                ERROR_CODES.INVALID_INPUT,
                'Location (lat, lng) is required'
            );
            return res.status(statusCode).json(response);
        }

        const pageNum = parseInt(page, 10) || 1;
        const limitNum = Math.min(parseInt(limit, 10) || 20, 50);
        const offset = (pageNum - 1) * limitNum;

        const twelveHoursAgo = new Date(Date.now() - 12 * 60 * 60 * 1000).toISOString();

        const { data: jobs, error, count } = await supabase
            .from('jobs')
            .select(`
                *,
                service:services(id, name, icon_url, base_price),
                customer:users!customer_id(id, full_name, phone, profile_image_url, rating)
            `, { count: 'exact' })
            .eq('status', 'pending')
            .gt('created_at', twelveHoursAgo)
            .order('created_at', { ascending: false })
            .range(offset, offset + limitNum - 1);

        if (error) throw error;

        return res.json(
            responseFormatter.successPaginated(jobs, {
                page: pageNum,
                limit: limitNum,
                total: count || 0,
                totalPages: Math.ceil((count || 0) / limitNum),
                hasMore: offset + limitNum < (count || 0)
            })
        );
    } catch (error) {
        console.error('Get Nearby Jobs Error:', error);
        const { response, statusCode } = responseFormatter.error(
            ERROR_CODES.DATABASE_ERROR,
            error.message
        );
        return res.status(statusCode).json(response);
    }
};

// 3. Accept Job
export const acceptJob = async (req, res) => {
    try {
        const job = await jobService.accept(req.params.id, req.user.id);

        onJobAccepted(job.id);

        return res.json(
            responseFormatter.success(job, 'Job accepted')
        );
    } catch (error) {
        // Handle specific business errors
        if (error.code === 'JOB_NOT_FOUND') {
            const { response, statusCode } = responseFormatter.error(ERROR_CODES.JOB_NOT_FOUND, error.message, HTTP_STATUS.NOT_FOUND);
            return res.status(statusCode).json(response);
        }
        if (error.code === 'INVALID_STATUS_TRANSITION' || error.message.includes('taken')) {
            const { response, statusCode } = responseFormatter.error(ERROR_CODES.JOB_ALREADY_ACCEPTED, error.message, HTTP_STATUS.CONFLICT);
            return res.status(statusCode).json(response);
        }

        const { response, statusCode } = responseFormatter.error(ERROR_CODES.ACCEPT_FAILED, error.message);
        return res.status(statusCode).json(response);
    }
};

// 4. Get My Jobs (Enhanced with full data & pagination)
export const getMyJobs = async (req, res) => {
    try {
        const { status, page = 1, limit = 20 } = req.query;
        const pageNum = parseInt(page, 10) || 1;
        const limitNum = Math.min(parseInt(limit, 10) || 20, 50);
        const offset = (pageNum - 1) * limitNum;

        // Build query with full relations
        let query = supabase
            .from('jobs')
            .select(`
                *,
                service:services(id, name, icon_url, base_price),
                customer:users!customer_id(id, full_name, phone, profile_image_url, rating),
                technician:users!technician_id(id, full_name, phone, profile_image_url, rating)
            `, { count: 'exact' })
            .or(`customer_id.eq.${req.user.id},technician_id.eq.${req.user.id}`)
            .neq('status', 'cancelled');

        // Optional status filter
        if (status) {
            query = query.eq('status', status);
        }

        // Execute query with pagination
        const { data: jobs, error, count } = await query
            .order('created_at', { ascending: false })
            .range(offset, offset + limitNum - 1);

        if (error) throw error;

        return res.json(
            responseFormatter.successPaginated(jobs, {
                page: pageNum,
                limit: limitNum,
                total: count || 0,
                totalPages: Math.ceil((count || 0) / limitNum),
                hasMore: offset + limitNum < (count || 0)
            })
        );
    } catch (error) {
        console.error('Get My Jobs Error:', error);
        const { response, statusCode } = responseFormatter.error(
            ERROR_CODES.DATABASE_ERROR,
            'Server error',
            HTTP_STATUS.INTERNAL_SERVER_ERROR
        );
        return res.status(statusCode).json(response);
    }
};

// 5. Complete Job
export const completeJob = async (req, res) => {
    try {
        const job = await jobService.complete(req.params.id, req.user.id);
        return res.json(responseFormatter.success(job, 'Job completed'));
    } catch (error) {
        const { response, statusCode } = responseFormatter.error(
            ERROR_CODES.INVALID_STATUS_TRANSITION,
            error.message
        );
        return res.status(statusCode).json(response);
    }
};

// 6. Set Price
export const setPrice = async (req, res) => {
    try {
        const { price, notes } = req.body;
        const job = await jobService.setPrice(req.params.id, req.user.id, price, notes);
        return res.json(responseFormatter.success(job, 'Price submitted'));
    } catch (error) {
        const { response, statusCode } = responseFormatter.error(
            ERROR_CODES.INVALID_INPUT,
            error.message
        );
        return res.status(statusCode).json(response);
    }
};

// 7. Confirm Price
export const confirmPrice = async (req, res) => {
    try {
        const job = await jobService.confirmPrice(req.params.id, req.user.id);
        return res.json(responseFormatter.success(job, 'Price confirmed'));
    } catch (error) {
        const { response, statusCode } = responseFormatter.error(
            ERROR_CODES.INVALID_STATUS_TRANSITION,
            error.message
        );
        return res.status(statusCode).json(response);
    }
};

// 8. Rate Job
export const rateJob = async (req, res) => {
    try {
        const { rating, review } = req.body;
        const job = await jobService.rate(req.params.id, req.user.id, rating, review);
        return res.json(responseFormatter.success(job, 'Rating submitted'));
    } catch (error) {
        const { response, statusCode } = responseFormatter.error(
            ERROR_CODES.INVALID_INPUT,
            error.message
        );
        return res.status(statusCode).json(response);
    }
};

// 9. Cancel Job
export const cancelJob = async (req, res) => {
    try {
        const { reason } = req.body;
        const job = await jobService.cancel(req.params.id, req.user.id, reason);

        cancelJobSearch(job.id);

        return res.json(responseFormatter.success(job, 'Job cancelled'));
    } catch (error) {
        const { response, statusCode } = responseFormatter.error(
            ERROR_CODES.INVALID_STATUS_TRANSITION,
            error.message
        );
        return res.status(statusCode).json(response);
    }
};

// 10. Get Job By ID (with full relations + proper not-found handling)
export const getJobById = async (req, res) => {
    try {
        const jobId = req.params.id;

        const { data: job, error } = await supabase
            .from('jobs')
            .select(`
                *,
                service:services(id, name, icon_url, base_price),
                customer:users!customer_id(id, full_name, phone, profile_image_url, rating),
                technician:users!technician_id(id, full_name, phone, profile_image_url, rating)
            `)
            .eq('id', jobId)
            .maybeSingle();

        // Real DB error (not PGRST116)
        if (error && error.code !== 'PGRST116') {
            console.error('Get Job By ID Error (DB):', error);
            const { response, statusCode } = responseFormatter.error(
                ERROR_CODES.DATABASE_ERROR,
                'Database error',
                HTTP_STATUS.INTERNAL_SERVER_ERROR
            );
            return res.status(statusCode).json(response);
        }

        // No rows (PGRST116 or job === null)
        if (!job) {
            const { response, statusCode } = responseFormatter.error(
                ERROR_CODES.JOB_NOT_FOUND,
                'Job not found',
                HTTP_STATUS.NOT_FOUND
            );
            return res.status(statusCode).json(response);
        }
        // Check if user is authorized (customer or technician involved in the job)
        // OR if the job is pending/searching (available for technicians to view)
        const isParticipant = job.customer_id === req.user.id || job.technician_id === req.user.id;
        const isAvailable = ['pending', 'searching'].includes(job.status);

        if (!isParticipant && !isAvailable) {
            const { response, statusCode } = responseFormatter.error(
                ERROR_CODES.UNAUTHORIZED,
                'Unauthorized',
                HTTP_STATUS.FORBIDDEN
            );
            return res.status(statusCode).json(response);
        }

        // NEW: Add computed fields for frontend
        const enrichedJob = {
            ...job,
            // Permissions for current user
            permissions: {
                canAccept: job.status === 'pending' && !job.technician_id && req.user.user_type === 'technician',
                canSetPrice: job.status === 'accepted' && job.technician_id === req.user.id,
                canConfirmPrice: job.status === 'price_pending' && job.customer_id === req.user.id,
                canComplete: job.status === 'in_progress' && job.technician_id === req.user.id,
                canRate: job.status === 'completed' && job.customer_id === req.user.id && !job.customer_rating,
                canCancel: !['completed', 'rated', 'cancelled'].includes(job.status) &&
                    (job.customer_id === req.user.id || job.technician_id === req.user.id)
            },
            // Metadata
            timeline: {
                createdAt: job.created_at,
                acceptedAt: job.accepted_at,
                priceConfirmedAt: job.price_confirmed_at,
                completedAt: job.completed_at,
                ratedAt: job.rated_at,
                cancelledAt: job.cancelled_at
            },
            // Price summary
            priceSummary: {
                initialPrice: job.initial_price,
                technicianProposedPrice: job.technician_price,
                finalPrice: job.final_price || job.technician_price,
                commission: job.technician_price ? Math.round(job.technician_price * 0.1) : 0
            }
        };

        return res.json(responseFormatter.success(enrichedJob));
    } catch (error) {
        console.error('Get Job By ID Error (Unhandled):', error);
        const { response, statusCode } = responseFormatter.error(
            ERROR_CODES.DATABASE_ERROR,
            'Server error',
            HTTP_STATUS.INTERNAL_SERVER_ERROR
        );
        return res.status(statusCode).json(response);
    }
};
