/**
 * Job Search Service
 * Handles smart matching of jobs to nearby technicians
 */
import { supabaseAdmin } from '../config/supabase.js';
import { notifyTechniciansWithPush } from './fcmService.js';

// Search tiers: [radius in meters, timeout in seconds]
const SEARCH_TIERS = [
    { radius: 2000, timeout: 120 },   // Tier 1: 2km, 2 minutes
    { radius: 5000, timeout: 180 },   // Tier 2: 5km, 3 minutes
    { radius: 10000, timeout: 300 }   // Tier 3: 10km, 5 minutes
];

// In-memory registry for active searches to support cancellation and proper flow control.
const activeSearches = new Map();
const SEARCHABLE_STATUSES = ['pending', 'searching', 'no_technician_found'];

async function isJobSearchable(jobId) {
    try {
        const { data: job, error } = await supabaseAdmin
            .from('jobs')
            .select('status, technician_id')
            .eq('id', jobId)
            .maybeSingle();

        if (error || !job) {
            return false;
        }

        return SEARCHABLE_STATUSES.includes(job.status) && !job.technician_id;
    } catch (_) {
        return false;
    }
}

/**
 * Start smart job search
 */
export async function startJobSearch(jobId, lat, lng, serviceId) {
    console.log(`🔍 [Job ${jobId}] Starting smart search...`);

    // Ensure a single active search process per job.
    cancelJobSearch(jobId);

    const state = {
        jobId,
        lat,
        lng,
        serviceId,
        tierIndex: 0,
        startTime: Date.now(),
        isCancelled: false
    };

    activeSearches.set(jobId, state);

    // Mark job as "searching" so UI and technicians see the correct lifecycle state.
    try {
        await supabaseAdmin
            .from('jobs')
            .update({
                status: 'searching',
                updated_at: new Date().toISOString()
            })
            .eq('id', jobId)
            .in('status', ['pending', 'searching', 'no_technician_found']);
    } catch (error) {
        console.warn(`⚠️ [Job ${jobId}] Failed to mark as searching:`, error?.message || error);
    }

    // Start first tier
    executeSearchTier(state).catch((error) => {
        console.error(`❌ [Job ${jobId}] Search execution failed:`, error);
        activeSearches.delete(jobId);
    });
}

/**
 * Execute search tier
 */
async function executeSearchTier(state) {
    try {
        // Stop immediately if cancelled or replaced.
        if (state.isCancelled || activeSearches.get(state.jobId) !== state) {
            return;
        }

        // Defensive DB-side guard:
        // if job left searchable states (e.g. cancelled) stop immediately.
        const searchable = await isJobSearchable(state.jobId);
        if (!searchable) {
            activeSearches.delete(state.jobId);
            return;
        }

        if (state.tierIndex >= SEARCH_TIERS.length) {
            // No technicians found in any tier
            await handleNoTechnicianFound(state);
            activeSearches.delete(state.jobId);
            return;
        }

        const tier = SEARCH_TIERS[state.tierIndex];
        const searchStartTime = Date.now();
        console.log(`📡 [Job ${state.jobId}] Tier ${state.tierIndex + 1}: Searching ${tier.radius}m`);

        // Find technicians in this tier (now with serviceId filtering)
        const technicians = await findTechnicians(
            state.lat,
            state.lng,
            tier.radius,
            state.serviceId  // Pass service for specialty filtering
        );

        const searchDuration = Date.now() - searchStartTime;

        // Log search for analytics (non-blocking)
        logSearch(state.jobId, state.tierIndex, tier.radius, technicians.length, searchDuration);

        if (technicians.length > 0) {
            // Re-check before notifying technicians in case status changed meanwhile.
            const stillSearchable = await isJobSearchable(state.jobId);
            if (!stillSearchable || state.isCancelled || activeSearches.get(state.jobId) !== state) {
                activeSearches.delete(state.jobId);
                return;
            }

            console.log(`✅ [Job ${state.jobId}] Found ${technicians.length} technicians in Tier ${state.tierIndex + 1} (${searchDuration}ms)`);

            // Send notifications to technicians
            await notifyTechnicians(state.jobId, technicians);

            // Wait for acceptance
            const accepted = await waitForAcceptance(state.jobId, tier.timeout, state);

            // Stop if cancelled while waiting.
            if (state.isCancelled || activeSearches.get(state.jobId) !== state) {
                return;
            }

            if (accepted) {
                activeSearches.delete(state.jobId);
                return;
            }

            // If job is no longer searchable after waiting, do not continue tiers.
            const canContinue = await isJobSearchable(state.jobId);
            if (!canContinue) {
                activeSearches.delete(state.jobId);
                return;
            }
        }

        console.log(`⏭️  [Job ${state.jobId}] No acceptance in Tier ${state.tierIndex + 1}, moving to next tier...`);

        // Move to next tier
        state.tierIndex++;
        setTimeout(() => {
            const current = activeSearches.get(state.jobId);
            if (!current || current.isCancelled || current !== state) return;
            executeSearchTier(current).catch((error) => {
                console.error(`❌ [Job ${state.jobId}] Next tier execution failed:`, error);
                activeSearches.delete(state.jobId);
            });
        }, 1000);

    } catch (error) {
        console.error(`❌ [Job ${state.jobId}] Error in tier execution:`, error);
        // Retry or fallback logic could go here
        activeSearches.delete(state.jobId);
    }
}

/**
 * Log search to analytics table (non-blocking)
 */
async function logSearch(jobId, tierIndex, radiusMeters, techniciansFound, durationMs) {
    try {
        await supabaseAdmin
            .from('search_logs')
            .insert({
                job_id: jobId,
                tier_index: tierIndex,
                radius_meters: radiusMeters,
                technicians_found: techniciansFound,
                search_duration_ms: durationMs
            });
    } catch (error) {
        // Don't fail search if logging fails
        console.warn('Failed to log search:', error.message);
    }
}

/**
 * Find technicians within radius using PostGIS RPC
 * Much faster than fetching all and filtering in JS
 */
async function findTechnicians(lat, lng, radius, serviceId = null) {
    try {
        const startTime = Date.now();

        // Use PostGIS-powered RPC for efficient spatial query
        const { data: technicians, error } = await supabaseAdmin
            .rpc('get_nearby_technicians', {
                lat: lat,
                long: lng,
                radius_meters: radius,
                service_type: serviceId
            });

        const duration = Date.now() - startTime;

        if (error) {
            console.error('Error in get_nearby_technicians RPC:', error);
            // Fallback to manual filtering if RPC fails
            return await findTechniciansFallback(lat, lng, radius);
        }

        if (!technicians || technicians.length === 0) {
            console.log(`📍 [Search] No technicians within ${radius}m (${duration}ms)`);
            return [];
        }

        // RPC already returns sorted by distance, but let's add rating consideration
        // Sort by: nearest first, then highest rating for same distance tier
        const sortedTechnicians = technicians.sort((a, b) => {
            // If distance difference is < 500m, prioritize rating
            const distDiff = (a.dist_meters || 0) - (b.dist_meters || 0);
            if (Math.abs(distDiff) < 500) {
                return (b.rating || 0) - (a.rating || 0);
            }
            return distDiff;
        });

        console.log(`📍 [Search] Found ${sortedTechnicians.length} technicians within ${radius}m (${duration}ms)`);
        return sortedTechnicians.slice(0, 10); // Limit to top 10

    } catch (error) {
        console.error('Error in findTechnicians:', error);
        return [];
    }
}

/**
 * Fallback: Manual distance calculation if RPC unavailable
 */
async function findTechniciansFallback(lat, lng, radius) {
    console.log('⚠️ Using fallback technician search (RPC unavailable)');

    const { data: technicians, error } = await supabaseAdmin
        .from('users')
        .select('id, full_name, phone, profile_image_url, rating, location')
        .eq('user_type', 'technician')
        .eq('is_online', true);

    if (error || !technicians) return [];

    const nearbyTechnicians = technicians
        .map(tech => {
            if (!tech.location) return null;

            let techLng, techLat;
            if (typeof tech.location === 'string') {
                const matches = tech.location.match(/POINT\(([-\d.]+) ([-\d.]+)\)/);
                if (matches) {
                    techLng = parseFloat(matches[1]);
                    techLat = parseFloat(matches[2]);
                }
            } else if (tech.location.coordinates) {
                [techLng, techLat] = tech.location.coordinates;
            }

            if (!techLng || !techLat) return null;

            const dist_meters = calculateDistance(lat, lng, techLat, techLng);
            if (dist_meters > radius) return null;

            return { ...tech, dist_meters };
        })
        .filter(Boolean)
        .sort((a, b) => a.dist_meters - b.dist_meters)
        .slice(0, 10);

    return nearbyTechnicians;
}

/**
 * Calculate distance between two coordinates (Haversine formula)
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371000; // Earth radius in meters
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLon = ((lon2 - lon1) * Math.PI) / 180;
    const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos((lat1 * Math.PI) / 180) *
        Math.cos((lat2 * Math.PI) / 180) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c; // Distance in meters
}

/**
 * Notify technicians about new job
 */
async function notifyTechnicians(jobId, technicians) {
    console.log(`📢 [Job ${jobId}] Notifying ${technicians.length} technicians...`);

    const notifications = technicians.map(tech => ({
        user_id: tech.id,
        type: 'new_job_offer',
        title: 'وظيفة جديدة متاحة',
        body: `طلب خدمة جديد بالقرب منك`,
        data: { job_id: jobId },
        is_read: false
    }));

    try {
        await supabaseAdmin
            .from('notifications')
            .insert(notifications);
        console.log(`✅ [Job ${jobId}] In-app notifications sent`);

        // Send FCM Push notifications
        await notifyTechniciansWithPush(jobId, technicians);
        console.log(`✅ [Job ${jobId}] FCM push notifications sent`);
    } catch (error) {
        console.error(`❌ [Job ${jobId}] Error sending notifications:`, error);
    }
}

/**
 * Wait for technician acceptance
 */
async function waitForAcceptance(jobId, timeoutSeconds, state) {
    return new Promise((resolve) => {
        const startTime = Date.now();
        const checkInterval = setInterval(async () => {
            if (state?.isCancelled) {
                clearInterval(checkInterval);
                resolve(false);
                return;
            }

            // Check if job was accepted
            const { data: job, error } = await supabaseAdmin
                .from('jobs')
                .select('status, technician_id')
                .eq('id', jobId)
                .single();

            if (error) {
                console.error(`Error checking job status:`, error);
                return;
            }

            if (job?.status === 'accepted') {
                console.log(`✅ [Job ${jobId}] Job accepted by technician ${job.technician_id}`);
                clearInterval(checkInterval);
                resolve(true);
                return;
            }

            // Stop search progression if job left searchable states.
            if (job && !SEARCHABLE_STATUSES.includes(job.status)) {
                clearInterval(checkInterval);
                resolve(false);
                return;
            }

            // Check timeout
            const elapsedSeconds = (Date.now() - startTime) / 1000;
            if (elapsedSeconds >= timeoutSeconds) {
                console.log(`⏱️  [Job ${jobId}] Tier timeout (${timeoutSeconds}s)`);
                clearInterval(checkInterval);
                resolve(false);
                return;
            }
        }, 5000); // Check every 5 seconds
    });
}

/**
 * Handle no technician found
 */
async function handleNoTechnicianFound(state) {
    if (state.isCancelled || activeSearches.get(state.jobId) !== state) return;

    // Last defensive guard before writing terminal search status.
    const searchable = await isJobSearchable(state.jobId);
    if (!searchable) return;

    console.log(`😔 [Job ${state.jobId}] No technician found in any tier`);

    const nextRetryTime = new Date(Date.now() + 3600000); // 1 hour from now

    // Update job status
    const { data: updatedJob, error: updateError } = await supabaseAdmin
        .from('jobs')
        .update({
            status: 'no_technician_found',
            search_attempts: 1,
            last_search_at: new Date().toISOString(),
            next_search_at: nextRetryTime.toISOString(),
            updated_at: new Date().toISOString()
        })
        .eq('id', state.jobId)
        .in('status', SEARCHABLE_STATUSES)
        .is('technician_id', null)
        .select('id')
        .maybeSingle();

    if (updateError || !updatedJob) {
        if (updateError) {
            console.error(`Error updating job:`, updateError);
        } else {
            console.log(`ℹ️ [Job ${state.jobId}] Skipped no_technician update (job no longer searchable)`);
        }
        return;
    }

    // Notify customer
    const { data: job } = await supabaseAdmin
        .from('jobs')
        .select('customer_id')
        .eq('id', state.jobId)
        .single();

    if (job) {
        await supabaseAdmin
            .from('notifications')
            .insert({
                user_id: job.customer_id,
                type: 'no_technician',
                title: 'لم يتم العثور على فني 😔',
                body: `لم يتم العثور على فني متاح حالياً. سيتم إعادة المحاولة الساعة ${nextRetryTime.toLocaleTimeString('ar-SA')}`,
                data: { job_id: state.jobId },
                is_read: false
            });
    }

    console.log(`📧 [Job ${state.jobId}] Customer notified`);
}

/**
 * Cleanup search (called when job is accepted)
 */
export function cleanupSearch(jobId) {
    console.log(`🧹 [Job ${jobId}] Cleaning up search`);
    const state = activeSearches.get(jobId);
    if (state) {
        state.isCancelled = true;
        activeSearches.delete(jobId);
    }
}

/**
 * Cancel search (called when job is cancelled)
 */
export function cancelJobSearch(jobId) {
    console.log(`🛑 [Job ${jobId}] Cancelling search`);
    cleanupSearch(jobId);
}

/**
 * Search Accepted (called when job is accepted)
 */
export function onJobAccepted(jobId) {
    console.log(`✅ [Job ${jobId}] Accepted callback triggering cleanup`);
    cleanupSearch(jobId);
}
