/**
 * Job Search Service
 * Handles smart matching of jobs to nearby technicians
 */

import { supabaseAdmin } from '../config/supabase.js';

// Search tiers: [radius in meters, timeout in seconds]
const SEARCH_TIERS = [
    { radius: 2000, timeout: 120 },   // Tier 1: 2km, 2 minutes
    { radius: 5000, timeout: 180 },   // Tier 2: 5km, 3 minutes
    { radius: 10000, timeout: 300 }   // Tier 3: 10km, 5 minutes
];

/**
 * Start smart job search
 */
export async function startJobSearch(jobId, lat, lng, serviceId) {
    console.log(`🔍 [Job ${jobId}] Starting smart search...`);

    const state = {
        jobId,
        lat,
        lng,
        serviceId,
        tierIndex: 0,
        startTime: Date.now()
    };

    // Start first tier
    executeSearchTier(state);
}

/**
 * Execute search tier
 */
async function executeSearchTier(state) {
    try {
        if (state.tierIndex >= SEARCH_TIERS.length) {
            // No technicians found in any tier
            await handleNoTechnicianFound(state);
            return;
        }

        const tier = SEARCH_TIERS[state.tierIndex];
        console.log(`📡 [Job ${state.jobId}] Tier ${state.tierIndex + 1}: Searching ${tier.radius}m`);

        // Find technicians in this tier
        const technicians = await findTechnicians(
            state.lat,
            state.lng,
            tier.radius
        );

        if (technicians.length > 0) {
            console.log(`✅ [Job ${state.jobId}] Found ${technicians.length} technicians in Tier ${state.tierIndex + 1}`);

            // Send notifications to technicians
            await notifyTechnicians(state.jobId, technicians);

            // Wait for acceptance
            await waitForAcceptance(state.jobId, tier.timeout);
            return;
        }

        console.log(`⏭️  [Job ${state.jobId}] No technicians in Tier ${state.tierIndex + 1}, moving to next tier...`);

        // Move to next tier
        state.tierIndex++;
        setTimeout(() => executeSearchTier(state), 1000);

    } catch (error) {
        console.error(`❌ [Job ${state.jobId}] Error in tier execution:`, error);
        // Retry or fallback logic could go here
    }
}

/**
 * Find technicians within radius
 */
async function findTechnicians(lat, lng, radius) {
    try {
        // Get all online technicians
        const { data: technicians, error } = await supabaseAdmin
            .from('users')
            .select('id, full_name, phone, profile_image_url, rating, location')
            .eq('user_type', 'technician')
            .eq('is_online', true);

        if (error) {
            console.error('Error fetching technicians:', error);
            return [];
        }

        if (!technicians || technicians.length === 0) {
            console.log('No online technicians available');
            return [];
        }

        // Filter by distance
        const nearbyTechnicians = technicians.filter(tech => {
            if (!tech.location) return false;

            try {
                // tech.location is Geography(POINT) in format: { coordinates: [lng, lat] } or String 'POINT(lng lat)'
                let techLng, techLat;

                if (typeof tech.location === 'string') {
                    // Handle WKT format 'POINT(lng lat)'
                    const matches = tech.location.match(/POINT\(([-\d.]+) ([-\d.]+)\)/);
                    if (matches) {
                        techLng = parseFloat(matches[1]);
                        techLat = parseFloat(matches[2]);
                    }
                } else if (tech.location.coordinates) {
                    // Handle GeoJSON format
                    [techLng, techLat] = tech.location.coordinates;
                }

                if (techLng === undefined || techLat === undefined) return false;

                const distance = calculateDistance(lat, lng, techLat, techLng);
                return distance <= radius;
            } catch (e) {
                console.warn('Error calculating distance:', e);
                return false;
            }
        });

        console.log(`📍 [Search] Found ${nearbyTechnicians.length} technicians within ${radius}m`);
        return nearbyTechnicians;

    } catch (error) {
        console.error('Error in findTechnicians:', error);
        return [];
    }
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
        console.log(`✅ [Job ${jobId}] Notifications sent`);
    } catch (error) {
        console.error(`❌ [Job ${jobId}] Error sending notifications:`, error);
    }
}

/**
 * Wait for technician acceptance
 */
async function waitForAcceptance(jobId, timeoutSeconds) {
    return new Promise((resolve) => {
        const startTime = Date.now();
        const checkInterval = setInterval(async () => {
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
    console.log(`😔 [Job ${state.jobId}] No technician found in any tier`);

    const nextRetryTime = new Date(Date.now() + 3600000); // 1 hour from now

    // Update job status
    const { error: updateError } = await supabaseAdmin
        .from('jobs')
        .update({
            status: 'no_technician_found',
            search_attempts: 1,
            last_search_at: new Date().toISOString(),
            next_search_at: nextRetryTime.toISOString(),
            updated_at: new Date().toISOString()
        })
        .eq('id', state.jobId);

    if (updateError) {
        console.error(`Error updating job:`, updateError);
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
    // Cancel any pending operations
}

/**
 * Cancel search (called when job is cancelled)
 */
export function cancelJobSearch(jobId) {
    console.log(`🛑 [Job ${jobId}] Cancelling search`);
    // Logic to stop search logic
}

/**
 * Search Accepted (called when job is accepted)
 */
export function onJobAccepted(jobId) {
    console.log(`✅ [Job ${jobId}] Accepted callback triggering cleanup`);
    cleanupSearch(jobId);
}
