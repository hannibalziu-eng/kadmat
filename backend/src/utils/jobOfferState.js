import { supabaseAdmin } from '../config/supabase.js';

export async function hasActivePendingOffers(jobId) {
    const { count, error } = await supabaseAdmin
        .from('job_offers')
        .select('id', { count: 'exact', head: true })
        .eq('job_id', jobId)
        .eq('status', 'pending')
        .eq('is_active', true);

    if (error) {
        throw new Error(`Failed to check active offers: ${error.message}`);
    }

    return (count || 0) > 0;
}
