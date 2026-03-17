import { supabase } from '../config/supabase.js';

const serviceSelect = [
    '*',
    'pricing_mode_default',
    'dispatch_mode_default',
    'is_catalog_enabled',
    'requires_quote',
    'service_config',
].join(', ');

// Get all active services
export const getServices = async (req, res) => {
    try {
        const { data: services, error, count } = await supabase
            .from('services')
            .select(serviceSelect, { count: 'exact' })
            .eq('is_active', true)
            .order('name', { ascending: true });

        if (error) throw error;

        return res.json({
            success: true,
            data: {
                services: services || [],
                count: count || services?.length || 0,
            },
            count: count || services?.length || 0,
            services: services || [],
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
            .select(serviceSelect)
            .eq('id', id)
            .eq('is_active', true)
            .maybeSingle();

        if (error) throw error;

        if (!service) {
            return res.status(404).json({ success: false, message: 'Service not found' });
        }

        let catalog_items = [];

        if (service.is_catalog_enabled) {
            const { data: items, error: catalogError } = await supabase
                .from('service_catalog_items')
                .select('*')
                .eq('service_id', id)
                .eq('is_active', true)
                .order('sort_order', { ascending: true })
                .order('name', { ascending: true });

            if (catalogError) throw catalogError;
            catalog_items = items || [];
        }

        const servicePayload = {
            ...service,
            catalog_items,
        };

        return res.json({
            success: true,
            data: {
                service: servicePayload,
            },
            service: servicePayload,
        });

    } catch (error) {
        console.error('Get Service Error:', error);
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};

// Get active catalog items for a service
export const getServiceCatalogItems = async (req, res) => {
    try {
        const { id } = req.params;

        const { data: service, error: serviceError } = await supabase
            .from('services')
            .select('id, is_active, is_catalog_enabled')
            .eq('id', id)
            .eq('is_active', true)
            .maybeSingle();

        if (serviceError) throw serviceError;

        if (!service) {
            return res.status(404).json({ success: false, message: 'Service not found' });
        }

        if (!service.is_catalog_enabled) {
            return res.json({
                success: true,
                data: {
                    items: [],
                    count: 0,
                },
                count: 0,
                items: [],
            });
        }

        const { data: items, error } = await supabase
            .from('service_catalog_items')
            .select('*', { count: 'exact' })
            .eq('service_id', id)
            .eq('is_active', true)
            .order('sort_order', { ascending: true })
            .order('name', { ascending: true });

        if (error) throw error;

        return res.json({
            success: true,
            data: {
                items: items || [],
                count: count || 0,
            },
            count: count || 0,
            items: items || [],
        });

    } catch (error) {
        console.error('Get Service Catalog Items Error:', error);
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};
