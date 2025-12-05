import { supabase, supabaseAdmin } from '../config/supabase.js';

/**
 * JobSearchService (The Matchmaker)
 * Handles the "Allocation" of jobs to technicians.
 * Pattern: Tiered Search (2km -> 5km -> 10km)
 */

// Configuration
const SEARCH_TIERS = [
    { radius: 2000, duration: 120000 },   // Tier 1: 2km for 2 mins
    { radius: 5000, duration: 180000 },   // Tier 2: 5km for 3 mins
    { radius: 10000, duration: 300000 },  // Tier 3: 10km for 5 mins
];

const MAX_RETRIES = 3;
const RETRY_DELAY = 2000;

// In-memory state (Use Redis in production)
const activeSearches = new Map();

export async function startJobSearch(jobId, lat, lng, serviceId) {
    console.log(`🔍 [Job ${jobId}] Starting smart search...`);

    const searchState = {
        jobId,
        serviceId,
        lat,
        lng,
        currentTierIndex: 0,
        notifiedTechnicians: new Set(),
        timer: null,
        retryCount: 0
    };

    activeSearches.set(jobId, searchState);
    await executeSearchTier(searchState);
}

async function executeSearchTier(state) {
    const tier = SEARCH_TIERS[state.currentTierIndex];

    // 1. Check if we exhausted all tiers
    if (!tier) {
        return handleNoTechnicianFound(state);
    }

    console.log(`📡 [Job ${state.jobId}] Tier ${state.currentTierIndex + 1}: Searching ${tier.radius}m`);

    try {
        // 2. Update Job Status/Metadata
        await updateJobSearchStatus(state.jobId, tier.radius);

        // 3. Find Technicians
        const technicians = await findTechnicians(state, tier.radius);

        console.log(`👷 [Job ${state.jobId}] Found ${technicians.length} new technicians`);

        // 4. Notify Technicians
        await notifyTechnicians(technicians, state.jobId);

        // Track notified
        technicians.forEach(t => state.notifiedTechnicians.add(t.id));

        // 5. Schedule Next Tier
        state.timer = setTimeout(() => {
            checkJobStatusAndProceed(state);
        }, tier.duration);

    } catch (error) {
        console.error(`❌ [Job ${state.jobId}] Error in tier execution:`, error);
        // Simple retry logic could go here
    }
}

async function checkJobStatusAndProceed(state) {
    try {
        // Check if job is still pending
        const { data: job } = await supabase
            .from('jobs')
            .select('status')
            .eq('id', state.jobId)
            .single();

        if (job && job.status === 'pending') {
            // Proceed to next tier
            state.currentTierIndex++;
            await executeSearchTier(state);
        } else {
            console.log(`🛑 [Job ${state.jobId}] Search stopped. Status: ${job?.status}`);
            cleanupSearch(state.jobId);
        }
    } catch (error) {
        console.error(`❌ [Job ${state.jobId}] Error checking status:`, error);
        cleanupSearch(state.jobId);
    }
}

async function findTechnicians(state, radius) {
    const { data, error } = await supabaseAdmin
        .rpc('find_nearby_technicians', {
            p_lat: state.lat,
            p_lng: state.lng,
            p_radius: radius,
            p_service_id: state.serviceId
        });

    if (error) throw error;

    // Filter out already notified
    return (data || []).filter(t => !state.notifiedTechnicians.has(t.id));
}

async function notifyTechnicians(technicians, jobId) {
    if (technicians.length === 0) return;

    const notifications = technicians.map(tech => ({
        user_id: tech.id,
        type: 'new_job_offer',
        title: 'طلب خدمة جديد 🔔',
        body: `يوجد طلب خدمة جديد بالقرب منك (${Math.round(tech.distance_meters)}m)`,
        data: { job_id: jobId },
        is_read: false
    }));

    const { error } = await supabaseAdmin
        .from('notifications')
        .insert(notifications);

    if (error) console.error('Failed to send notifications:', error);
}

async function updateJobSearchStatus(jobId, radius) {
    await supabaseAdmin
        .from('jobs')
        .update({
            status: 'searching',
            search_radius: radius,
            updated_at: new Date().toISOString()
        })
        .eq('id', jobId);
}

async function handleNoTechnicianFound(state) {
    console.log(`😔 [Job ${state.jobId}] No technician found.`);

    // Update Job Status
    await supabaseAdmin
        .from('jobs')
        .update({
            status: 'no_technician_found',
            updated_at: new Date().toISOString()
        })
        .eq('id', state.jobId);

    // Notify Customer
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
                title: 'عذراً 😔',
                body: 'لم يتم العثور على فني متاح حالياً. يرجى المحاولة لاحقاً.',
                data: { job_id: state.jobId }
            });
    }

    cleanupSearch(state.jobId);
}

export function cancelJobSearch(jobId) {
    cleanupSearch(jobId);
}

export function onJobAccepted(jobId) {
    cleanupSearch(jobId);
}

function cleanupSearch(jobId) {
    const state = activeSearches.get(jobId);
    if (state && state.timer) {
        clearTimeout(state.timer);
    }
    activeSearches.delete(jobId);
}
