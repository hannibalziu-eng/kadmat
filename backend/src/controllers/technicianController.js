import { supabase, supabaseAdmin } from '../config/supabase.js';
import Joi from 'joi';

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
            return res.status(400).json({ error: error.details[0].message });
        }

        // Update technician location in the database
        // Assuming 'technicians' table has a 'location' column of type geography(Point)
        // PostGIS syntax: 'POINT(long lat)'
        const { data, error: dbError } = await supabaseAdmin
            .from('users')
            .update({
                location: `POINT(${longitude} ${latitude})`
            })
            .eq('id', userId)
            .select()
            .maybeSingle();

        if (dbError) {
            console.error('Database error:', dbError);
            return res.status(500).json({ error: 'Failed to update location' });
        }

        if (!data) {
            return res.status(404).json({ error: 'User not found or permission denied' });
        }

        res.json({ message: 'Location updated successfully', data });
    } catch (error) {
        console.error('Update location error:', error);
        res.status(500).json({ error: 'Internal server error' });
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
            return res.status(400).json({ error: error.details[0].message });
        }

        const { data, error: dbError } = await supabaseAdmin
            .from('users')
            .update({ is_online: isOnline })
            .eq('id', userId)
            .select()
            .maybeSingle();

        if (dbError) {
            console.error('Database error:', dbError);
            return res.status(500).json({ error: 'Failed to update status' });
        }

        if (!data) {
            return res.status(404).json({ error: 'User not found or permission denied' });
        }

        res.json({ message: 'Status updated successfully', data });

    } catch (error) {
        console.error('Toggle status error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
};

export const getTechnicianProfile = async (req, res) => {
    try {
        const { id } = req.params;

        // 1. Fetch Technician Basic Info
        const { data: technician, error: userError } = await supabaseAdmin
            .from('users')
            .select('id, full_name, profile_image_url, rating, created_at, user_type')
            .eq('id', id)
            .eq('user_type', 'technician')
            .single();

        if (userError || !technician) {
            return res.status(404).json({ error: 'Technician not found' });
        }

        // 2. Fetch Stats (Completed Jobs Count)
        const { count: completedJobsCount, error: countError } = await supabaseAdmin
            .from('jobs')
            .select('id', { count: 'exact', head: true })
            .eq('technician_id', id)
            .eq('status', 'completed');

        // 3. Fetch Portfolio
        const { data: portfolio, error: portfolioError } = await supabaseAdmin
            .from('technician_portfolio')
            .select('*')
            .eq('technician_id', id)
            .order('project_date', { ascending: false });

        // 4. Fetch Reviews
        const { data: reviews, error: reviewsError } = await supabaseAdmin
            .from('reviews')
            .select(`
                id, rating, comment, created_at,
                reviewer:users!reviewer_id(full_name, profile_image_url)
            `)
            .eq('reviewee_id', id)
            .order('created_at', { ascending: false })
            .limit(20);

        const profileData = {
            ...technician,
            stats: {
                completedJobs: completedJobsCount || 0,
                rating: technician.rating || 5.0,
                totalReviews: reviews ? reviews.length : 0 // Should ideally be a count query
            },
            portfolio: portfolio || [],
            reviews: reviews || []
        };

        res.json({
            message: 'Profile fetched successfully',
            data: profileData
        });

    } catch (error) {
        console.error('Get profile error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
};
