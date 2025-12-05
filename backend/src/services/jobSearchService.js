import { supabase, supabaseAdmin } from '../config/supabase.js';

// Active job searches (in-memory for now, could use Redis for production)
const activeSearches = new Map();

// Search tiers configuration
const SEARCH_TIERS = [
    { radius: 2000, duration: 120000 },   // 2km for 2 minutes
    { radius: 5000, duration: 180000 },   // 5km for 3 minutes
    { radius: 10000, duration: 300000 },  // 10km for 5 minutes
];

/**
 * Start searching for technicians for a job
 */
export async function startJobSearch(jobId, customerLat, customerLng, serviceId) {
    console.log(`🔍 Starting smart search for job ${jobId}`);

    const searchState = {
        jobId,
        serviceId,
        customerLat,
        customerLng,
        currentTier: 0,
        startedAt: Date.now(),
        notifiedTechnicians: new Set(),
        timer: null,
    };

    activeSearches.set(jobId, searchState);

    // Start first tier
    await executeSearchTier(searchState);
}

/**
 * Execute search for current tier
 */
async function executeSearchTier(searchState) {
    const tier = SEARCH_TIERS[searchState.currentTier];
    if (!tier) {
        // All tiers exhausted
        await handleNoTechnicianFound(searchState.jobId);
        return;
    }

    console.log(`📡 Tier ${searchState.currentTier + 1}: Searching within ${tier.radius / 1000}km`);

    // Update job with current search radius
    await updateJobSearchRadius(searchState.jobId, tier.radius);

    // Find technicians in this radius
    const technicians = await findNearbyTechnicians(
        searchState.customerLat,
        searchState.customerLng,
        tier.radius,
        searchState.serviceId,
        searchState.notifiedTechnicians
    );

    console.log(`👷 Found ${technicians.length} new technicians in tier ${searchState.currentTier + 1}`);

    // Notify technicians
    for (const tech of technicians) {
        await notifyTechnician(tech, searchState.jobId);
        searchState.notifiedTechnicians.add(tech.id);
    }

    // Broadcast update to customer via Supabase Realtime
    await broadcastSearchUpdate(searchState.jobId, {
        radius: tier.radius,
        tier: searchState.currentTier + 1,
        technicianCount: searchState.notifiedTechnicians.size,
    });

    // Set timer for next tier
    searchState.timer = setTimeout(async () => {
        // Check if job is still pending
        const { data: job } = await supabase
            .from('jobs')
            .select('status')
            .eq('id', searchState.jobId)
            .single();

        if (job?.status === 'pending') {
            searchState.currentTier++;
            await executeSearchTier(searchState);
        } else {
            // Job was accepted or cancelled, clean up
            cleanupSearch(searchState.jobId);
        }
    }, tier.duration);
}

/**
 * Find technicians within radius
 */
async function findNearbyTechnicians(lat, lng, radiusMeters, serviceId, alreadyNotified) {
    try {
        const { data, error } = await supabaseAdmin
            .rpc('find_nearby_technicians', {
                p_lat: lat,
                p_lng: lng,
                p_radius: radiusMeters,
                p_service_id: serviceId,
            });

        if (error) {
            console.error('Error finding technicians:', error);
            return [];
        }

        // Filter out already notified technicians
        return (data || []).filter(t => !alreadyNotified.has(t.id));
    } catch (e) {
        console.error('Exception finding technicians:', e);
        return [];
    }
}

/**
 * Update job with current search radius (for frontend)
 */
async function updateJobSearchRadius(jobId, radius) {
    // Update metadata column or create separate table
    await supabaseAdmin
        .from('jobs')
        .update({
            search_radius: radius,
            updated_at: new Date().toISOString()
        })
        .eq('id', jobId);
}

/**
 * Notify a technician about the job
 */
async function notifyTechnician(technician, jobId) {
    console.log(`📲 Notifying technician ${technician.full_name} (${technician.id})`);

    // Insert notification in database (will trigger Realtime)
    await supabaseAdmin
        .from('notifications')
        .insert({
            user_id: technician.id,
            type: 'new_job',
            title: 'طلب خدمة جديد 🔔',
            body: 'يوجد طلب خدمة جديد قريب منك!',
            data: { job_id: jobId },
            is_read: false,
        });

    // TODO: Add Firebase Cloud Messaging for push notifications
}

/**
 * Broadcast search update via Supabase Realtime
 */
async function broadcastSearchUpdate(jobId, data) {
    // Update jobs table to trigger realtime subscription
    await supabaseAdmin
        .from('jobs')
        .update({
            search_data: data,
            updated_at: new Date().toISOString()
        })
        .eq('id', jobId);
}

/**
 * Handle case when no technician is found after all tiers
 */
async function handleNoTechnicianFound(jobId) {
    console.log(`😔 No technician found for job ${jobId}`);

    await supabaseAdmin
        .from('jobs')
        .update({
            status: 'no_technician_found',
            updated_at: new Date().toISOString()
        })
        .eq('id', jobId);

    cleanupSearch(jobId);
}

/**
 * Clean up search state
 */
function cleanupSearch(jobId) {
    const search = activeSearches.get(jobId);
    if (search?.timer) {
        clearTimeout(search.timer);
    }
    activeSearches.delete(jobId);
    console.log(`🧹 Cleaned up search for job ${jobId}`);
}

/**
 * Cancel an active search
 */
export function cancelJobSearch(jobId) {
    cleanupSearch(jobId);
}

/**
 * Called when a technician accepts a job
 */
export function onJobAccepted(jobId) {
    cleanupSearch(jobId);
}

export default {
    startJobSearch,
    cancelJobSearch,
    onJobAccepted,
};
