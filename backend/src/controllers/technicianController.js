import { supabaseAdmin } from '../config/supabase.js';
import Joi from 'joi';
import { responseFormatter, ERROR_CODES, HTTP_STATUS } from '../utils/responseFormatter.js';

export const updateLocation = async (req, res) => {
    try {
        const { latitude, longitude } = req.body;
        const userId = req.user.id;

        const schema = Joi.object({
            latitude: Joi.number().required(),
            longitude: Joi.number().required(),
        });

        const { error } = schema.validate({ latitude, longitude });
        if (error) {
            const formatted = responseFormatter.error(
                ERROR_CODES.VALIDATION_FAILED,
                error.details[0].message,
                HTTP_STATUS.BAD_REQUEST
            );
            return res.status(formatted.statusCode).json(formatted.response);
        }

        // Update technician location in the database
        // Assuming 'technicians' table has a 'location' column of type geography(Point)
        // PostGIS syntax with SRID: 'SRID=4326;POINT(long lat)'
        const { data, error: dbError } = await supabaseAdmin
            .from('users')
            .update({
                location: `SRID=4326;POINT(${longitude} ${latitude})`,
                updated_at: new Date().toISOString()
            })
            .eq('id', userId)
            .select()
            .maybeSingle();

        if (dbError) {
            console.error('Database error:', dbError);
            const formatted = responseFormatter.error(
                ERROR_CODES.DATABASE_ERROR,
                'Failed to update location',
                HTTP_STATUS.INTERNAL_SERVER_ERROR
            );
            return res.status(formatted.statusCode).json(formatted.response);
        }

        if (!data) {
            const formatted = responseFormatter.error(
                ERROR_CODES.NOT_FOUND,
                'User not found or permission denied',
                HTTP_STATUS.NOT_FOUND
            );
            return res.status(formatted.statusCode).json(formatted.response);
        }

        res.json(responseFormatter.success(data, 'Location updated successfully'));
    } catch (error) {
        console.error('Update location error:', error);
        const formatted = responseFormatter.error(
            ERROR_CODES.SERVER_ERROR,
            'Internal server error',
            HTTP_STATUS.INTERNAL_SERVER_ERROR
        );
        res.status(formatted.statusCode).json(formatted.response);
    }
};

export const toggleStatus = async (req, res) => {
    try {
        const { isOnline } = req.body;
        const userId = req.user.id;

        const schema = Joi.object({
            isOnline: Joi.boolean().required(),
        });

        const { error } = schema.validate({ isOnline });
        if (error) {
            const formatted = responseFormatter.error(
                ERROR_CODES.VALIDATION_FAILED,
                error.details[0].message,
                HTTP_STATUS.BAD_REQUEST
            );
            return res.status(formatted.statusCode).json(formatted.response);
        }

        const { data, error: dbError } = await supabaseAdmin
            .from('users')
            .update({ is_online: isOnline })
            .eq('id', userId)
            .select()
            .maybeSingle();

        if (dbError) {
            console.error('Database error:', dbError);
            const formatted = responseFormatter.error(
                ERROR_CODES.DATABASE_ERROR,
                'Failed to update status',
                HTTP_STATUS.INTERNAL_SERVER_ERROR
            );
            return res.status(formatted.statusCode).json(formatted.response);
        }

        if (!data) {
            const formatted = responseFormatter.error(
                ERROR_CODES.NOT_FOUND,
                'User not found or permission denied',
                HTTP_STATUS.NOT_FOUND
            );
            return res.status(formatted.statusCode).json(formatted.response);
        }

        res.json(responseFormatter.success(data, 'Status updated successfully'));

    } catch (error) {
        console.error('Toggle status error:', error);
        const formatted = responseFormatter.error(
            ERROR_CODES.SERVER_ERROR,
            'Internal server error',
            HTTP_STATUS.INTERNAL_SERVER_ERROR
        );
        res.status(formatted.statusCode).json(formatted.response);
    }
};

export const getTechnicianProfile = async (req, res) => {
    try {
        const { id } = req.params;

        // 1. Fetch Technician Basic Info
        const { data: technician, error: userError } = await supabaseAdmin
            .from('users')
            .select('id, full_name, profile_image_url, rating, created_at, user_type, service:service_id(name_ar)')
            .eq('id', id)
            .eq('user_type', 'technician')
            .single();

        if (userError || !technician) {
            const formatted = responseFormatter.error(
                ERROR_CODES.NOT_FOUND,
                'Technician not found',
                HTTP_STATUS.NOT_FOUND
            );
            return res.status(formatted.statusCode).json(formatted.response);
        }

        // 2/3/4. Fetch profile aggregates in parallel to reduce latency.
        const [
            { count: completedJobsCount, error: countError },
            { data: portfolio, error: portfolioError },
            { data: reviews, error: reviewsError }
        ] = await Promise.all([
            supabaseAdmin
                .from('jobs')
                .select('id', { count: 'exact', head: true })
                .eq('technician_id', id)
                .in('status', ['completed', 'rated']),
            supabaseAdmin
                .from('technician_portfolio')
                .select('*')
                .eq('technician_id', id)
                .order('project_date', { ascending: false }),
            supabaseAdmin
                .from('reviews')
                .select(`
                    id, rating, comment, created_at,
                    reviewer:users!reviewer_id(full_name, profile_image_url)
                `)
                .eq('reviewee_id', id)
                .order('created_at', { ascending: false })
                .limit(20)
        ]);

        if (countError) {
            console.warn(`⚠️ getTechnicianProfile count error (${id}):`, countError.message);
        }
        if (portfolioError) {
            console.warn(`⚠️ getTechnicianProfile portfolio error (${id}):`, portfolioError.message);
        }
        if (reviewsError) {
            console.warn(`⚠️ getTechnicianProfile reviews error (${id}):`, reviewsError.message);
        }

        const profileData = {
            ...technician,
            stats: {
                completedJobs: completedJobsCount || 0,
                rating: technician.rating || 5.0,
                totalReviews: reviews ? reviews.length : 0 // Should ideally be a count query
            },
            portfolio: portfolio || [],
            reviews: reviews || [],
            specialization: technician.service?.name_ar || 'فني خدمات عامة'
        };

        res.json(responseFormatter.success(profileData, 'Profile fetched successfully'));

    } catch (error) {
        console.error('Get profile error:', error);
        const formatted = responseFormatter.error(
            ERROR_CODES.SERVER_ERROR,
            'Internal server error',
            HTTP_STATUS.INTERNAL_SERVER_ERROR
        );
        res.status(formatted.statusCode).json(formatted.response);
    }
};

export const updateProfile = async (req, res) => {
    try {
        const { full_name, title, bio, location } = req.body;
        const userId = req.user.id;

        // Validation
        const schema = Joi.object({
            full_name: Joi.string().min(3).required(),
            title: Joi.string().allow('', null),
            bio: Joi.string().allow('', null),
            location: Joi.string().allow('', null)
        });

        const { error } = schema.validate({ full_name, title, bio, location });
        if (error) {
            const formatted = responseFormatter.error(
                ERROR_CODES.VALIDATION_FAILED,
                error.details[0].message,
                HTTP_STATUS.BAD_REQUEST
            );
            return res.status(formatted.statusCode).json(formatted.response);
        }

        const { data, error: dbError } = await supabaseAdmin
            .from('users')
            .update({
                full_name,
                title,
                bio,
                location // Assuming simple string for display location, or handle geography separately if needed
            })
            .eq('id', userId)
            .select()
            .single();

        if (dbError) throw dbError;

        res.json(responseFormatter.success(data, 'Profile updated successfully'));
    } catch (error) {
        console.error('Update profile error:', error);
        const formatted = responseFormatter.error(
            ERROR_CODES.DATABASE_ERROR,
            'Failed to update profile',
            HTTP_STATUS.INTERNAL_SERVER_ERROR
        );
        res.status(formatted.statusCode).json(formatted.response);
    }
};

export const addPortfolioWork = async (req, res) => {
    try {
        const { title, description, image_url, completion_date } = req.body;
        const userId = req.user.id;

        const schema = Joi.object({
            title: Joi.string().required(),
            description: Joi.string().allow('', null),
            image_url: Joi.string().required(),
            completion_date: Joi.string().required()
        });

        const { error } = schema.validate({ title, description, image_url, completion_date });
        if (error) {
            const formatted = responseFormatter.error(
                ERROR_CODES.VALIDATION_FAILED,
                error.details[0].message,
                HTTP_STATUS.BAD_REQUEST
            );
            return res.status(formatted.statusCode).json(formatted.response);
        }

        const { data, error: dbError } = await supabaseAdmin
            .from('technician_portfolio')
            .insert({
                technician_id: userId,
                title,
                description,
                image_url,
                project_date: completion_date // Mapping completion_date to project_date
            })
            .select()
            .single();

        if (dbError) throw dbError;

        res
            .status(HTTP_STATUS.CREATED)
            .json(responseFormatter.success(data, 'Work added successfully'));
    } catch (error) {
        console.error('Add portfolio error:', error);
        const formatted = responseFormatter.error(
            ERROR_CODES.DATABASE_ERROR,
            'Failed to add portfolio work',
            HTTP_STATUS.INTERNAL_SERVER_ERROR
        );
        res.status(formatted.statusCode).json(formatted.response);
    }
};

export const deletePortfolioWork = async (req, res) => {
    try {
        const { id } = req.params;
        const userId = req.user.id;

        const { error } = await supabaseAdmin
            .from('technician_portfolio')
            .delete()
            .eq('id', id)
            .eq('technician_id', userId); // Ensure ownership

        if (error) throw error;

        res.json(responseFormatter.success(null, 'Work deleted successfully'));
    } catch (error) {
        console.error('Delete portfolio error:', error);
        const formatted = responseFormatter.error(
            ERROR_CODES.DATABASE_ERROR,
            'Failed to delete portfolio work',
            HTTP_STATUS.INTERNAL_SERVER_ERROR
        );
        res.status(formatted.statusCode).json(formatted.response);
    }
};
