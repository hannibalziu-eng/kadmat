import { supabase, supabaseAdmin } from '../config/supabase.js';

// Active job searches (in-memory for now)
// Note: For production with multiple servers, use Redis
const activeSearches = new Map();

// Search tiers configuration
const SEARCH_TIERS = [
    { radius: 2000, duration: 120000 },   // 2km for 2 minutes
    { radius: 5000, duration: 180000 },   // 5km for 3 minutes
    { radius: 10000, duration: 300000 },  // 10km for 5 minutes
];

// Retry configuration
const MAX_RETRIES = 3;
const RETRY_DELAY = 2000; // 2 seconds

/**
 * Start searching for technicians for a job
 */
export async function startJobSearch(jobId, customerLat, customerLng, serviceId) {
    console.log(`🔍 Starting smart search for job ${jobId}`);

    try {
        const searchState = {
            jobId,
            serviceId,
            customerLat,
            customerLng,
            currentTier: 0,
            startedAt: Date.now(),
            notifiedTechnicians: new Set(),
            timer: null,
            retryCount: 0,
        };

        activeSearches.set(jobId, searchState);

        // Start first tier
        await executeSearchTier(searchState);
    } catch (error) {
        console.error(`❌ Failed to start search for job ${jobId}:`, error);
        // Don't throw - let the job stay in pending state
    }
}

/**
 * Execute search for current tier with error handling
 */
async function executeSearchTier(searchState) {
    const tier = SEARCH_TIERS[searchState.currentTier];

    if (!tier) {
        // All tiers exhausted
        await handleNoTechnicianFound(searchState.jobId);
        return;
    }

    console.log(`📡 Tier ${searchState.currentTier + 1}: Searching within ${tier.radius / 1000}km`);

    try {
        // Update job with current search radius
        await updateJobSearchRadius(searchState.jobId, tier.radius);

        // Find technicians in this radius
        const technicians = await findNearbyTechniciansWithRetry(
            searchState.customerLat,
            searchState.customerLng,
            tier.radius,
            searchState.serviceId,
            searchState.notifiedTechnicians
        );

        console.log(`👷 Found ${technicians.length} new technicians in tier ${searchState.currentTier + 1}`);

        // Notify technicians with individual error handling
        await notifyTechniciansParallel(technicians, searchState);

        // Broadcast update to customer via Supabase Realtime
        await broadcastSearchUpdate(searchState.jobId, {
            radius: tier.radius,
            tier: searchState.currentTier + 1,
            technicianCount: searchState.notifiedTechnicians.size,
        });

        // Reset retry count on success
        searchState.retryCount = 0;

    } catch (error) {
        console.error(`❌ Error in tier ${searchState.currentTier + 1}:`, error);

        // Retry logic
        if (searchState.retryCount < MAX_RETRIES) {
            searchState.retryCount++;
            console.log(`🔄 Retrying tier (attempt ${searchState.retryCount}/${MAX_RETRIES})...`);
            setTimeout(() => executeSearchTier(searchState), RETRY_DELAY);
            return;
        }

        // Max retries reached, move to next tier
        console.log(`⚠️ Max retries reached, moving to next tier`);
    }

    // Schedule next tier
    scheduleNextTier(searchState, tier.duration);
}

/**
 * Schedule the next tier search
 */
function scheduleNextTier(searchState, duration) {
    searchState.timer = setTimeout(async () => {
        try {
            // Check if job is still pending
            const { data: job, error } = await supabase
                .from('jobs')
                .select('status')
                .eq('id', searchState.jobId)
                .single();

            if (error) {
                console.error(`Error checking job status:`, error);
                cleanupSearch(searchState.jobId);
                return;
            }

            if (job?.status === 'pending') {
                searchState.currentTier++;
                searchState.retryCount = 0; // Reset retries for new tier
                await executeSearchTier(searchState);
            } else {
                // Job was accepted or cancelled, clean up
                console.log(`📋 Job ${searchState.jobId} status changed to ${job?.status}`);
                cleanupSearch(searchState.jobId);
            }
        } catch (error) {
            console.error(`Error in tier scheduler:`, error);
            cleanupSearch(searchState.jobId);
        }
    }, duration);
}

/**
 * Find technicians with retry logic
 */
async function findNearbyTechniciansWithRetry(lat, lng, radiusMeters, serviceId, alreadyNotified, retries = 0) {
    try {
        const { data, error } = await supabaseAdmin
            .rpc('find_nearby_technicians', {
                p_lat: lat,
                p_lng: lng,
                p_radius: radiusMeters,
                p_service_id: serviceId,
            });

        if (error) {
            throw error;
        }

        // Filter out already notified technicians
        return (data || []).filter(t => !alreadyNotified.has(t.id));
    } catch (error) {
        console.error(`Error finding technicians (attempt ${retries + 1}):`, error.message);

        if (retries < MAX_RETRIES) {
            await sleep(RETRY_DELAY);
            return findNearbyTechniciansWithRetry(lat, lng, radiusMeters, serviceId, alreadyNotified, retries + 1);
        }

        // Return empty array on max retries
        return [];
    }
}

/**
 * Notify technicians in parallel with individual error handling
 */
async function notifyTechniciansParallel(technicians, searchState) {
    const results = await Promise.allSettled(
        technicians.map(tech => notifyTechnicianSafe(tech, searchState.jobId))
    );

    // Log results and update notified set
    results.forEach((result, index) => {
        const tech = technicians[index];
        if (result.status === 'fulfilled') {
            searchState.notifiedTechnicians.add(tech.id);
        } else {
            console.warn(`⚠️ Failed to notify ${tech.full_name}:`, result.reason?.message);
        }
    });
}

/**
 * Notify a technician with error handling
 */
async function notifyTechnicianSafe(technician, jobId) {
    try {
        console.log(`📲 Notifying technician ${technician.full_name} (${technician.id})`);

        const { error } = await supabaseAdmin
            .from('notifications')
            .insert({
                user_id: technician.id,
                type: 'new_job',
                title: 'طلب خدمة جديد 🔔',
                body: `يوجد طلب خدمة جديد على بعد ${Math.round(technician.distance_meters / 100) / 10} كم`,
                data: { job_id: jobId },
                is_read: false,
            });

        if (error) throw error;

        return true;
    } catch (error) {
        console.error(`Failed to notify technician ${technician.id}:`, error.message);
        throw error; // Re-throw for Promise.allSettled
    }
}

/**
 * Update job with current search radius (for frontend)
 */
async function updateJobSearchRadius(jobId, radius) {
    try {
        const { error } = await supabaseAdmin
            .from('jobs')
            .update({
                search_radius: radius,
                updated_at: new Date().toISOString()
            })
            .eq('id', jobId);

        if (error) throw error;
    } catch (error) {
        console.error(`Failed to update search radius:`, error.message);
        // Don't throw - this is not critical
    }
}

/**
 * Broadcast search update via Supabase Realtime
 */
async function broadcastSearchUpdate(jobId, data) {
    try {
        const { error } = await supabaseAdmin
            .from('jobs')
            .update({
                search_data: data,
                updated_at: new Date().toISOString()
            })
            .eq('id', jobId);

        if (error) throw error;
    } catch (error) {
        console.error(`Failed to broadcast update:`, error.message);
        // Don't throw - this is not critical
    }
}

/**
 * Handle case when no technician is found after all tiers
 */
async function handleNoTechnicianFound(jobId) {
    console.log(`😔 No technician found for job ${jobId} after all tiers`);

    try {
        // Notify customer
        const { data: job } = await supabase
            .from('jobs')
            .select('customer_id')
            .eq('id', jobId)
            .single();

        if (job?.customer_id) {
            await supabaseAdmin
                .from('notifications')
                .insert({
                    user_id: job.customer_id,
                    type: 'no_technician',
                    title: 'عذراً 😔',
                    body: 'لم نتمكن من إيجاد فني متاح حالياً. حاول مرة أخرى لاحقاً.',
                    data: { job_id: jobId },
                });
        }

        // Update job status
        await supabaseAdmin
            .from('jobs')
            .update({
                status: 'cancelled',
                cancel_reason: 'لا يوجد فني متاح',
                cancelled_at: new Date().toISOString(),
                updated_at: new Date().toISOString()
            })
            .eq('id', jobId);

    } catch (error) {
        console.error(`Error handling no technician found:`, error);
    } finally {
        cleanupSearch(jobId);
    }
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

/**
 * Get active search info (for debugging/monitoring)
 */
export function getActiveSearches() {
    const searches = [];
    for (const [jobId, state] of activeSearches) {
        searches.push({
            jobId,
            currentTier: state.currentTier,
            notifiedCount: state.notifiedTechnicians.size,
            elapsedSeconds: Math.round((Date.now() - state.startedAt) / 1000),
        });
    }
    return searches;
}

/**
 * Utility: Sleep function
 */
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

export default {
    startJobSearch,
    cancelJobSearch,
    onJobAccepted,
    getActiveSearches,
};
