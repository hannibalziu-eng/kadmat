import { supabase } from '../config/supabase.js';

// Get all active services
export const getServices = async (req, res) => {
    try {
        const { data: services, error } = await supabase
            .from('services')
            .select('*')
            .eq('is_active', true)
            .order('name', { ascending: true });

        if (error) throw error;

        return res.json({
            success: true,
            data: {
                services,
                count: services.length,
            },
            count: services.length,
            services
        });

    } catch (error) {
        console.error('Get Services Error:', error);
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};

// Get single service by ID
export const getServiceById = async (req, res) => {
    try {
        const { id } = req.params;

        const { data: service, error } = await supabase
            .from('services')
            .select('*')
            .eq('id', id)
            .maybeSingle();

        if (error) throw error;

        if (!service) {
            return res.status(404).json({ success: false, message: 'Service not found' });
        }

        return res.json({
            success: true,
            data: {
                service,
            },
            service,
        });

    } catch (error) {
        console.error('Get Service Error:', error);
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};
