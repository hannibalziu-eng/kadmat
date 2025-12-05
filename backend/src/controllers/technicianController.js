import { supabase } from '../config/supabase.js';
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
        const { data, error: dbError } = await supabase
            .from('technicians')
            .update({
                location: `POINT(${longitude} ${latitude})`,
                last_location_update: new Date().toISOString(),
            })
            .eq('id', userId)
            .select()
            .single();

        if (dbError) {
            console.error('Database error:', dbError);
            return res.status(500).json({ error: 'Failed to update location' });
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

        const { data, error: dbError } = await supabase
            .from('technicians')
            .update({ is_online: isOnline })
            .eq('id', userId)
            .select()
            .single();

        if (dbError) {
            console.error('Database error:', dbError);
            return res.status(500).json({ error: 'Failed to update status' });
        }

        res.json({ message: 'Status updated successfully', data });

    } catch (error) {
        console.error('Toggle status error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
}
