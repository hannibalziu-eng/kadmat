/**
 * Job Retry Scheduler
 * Automatically retries search for jobs with no technicians found
 */

import cron from 'node-cron';
import { supabaseAdmin } from '../config/supabase.js';
import { startJobSearch } from '../services/jobSearchService.js';
import { hasActivePendingOffers } from '../utils/jobOfferState.js';

// Run every hour at minute 0
const RETRY_SCHEDULE = '0 * * * *'; // 00:00, 01:00, 02:00, etc.
const MAX_RETRIES = 3; // Max 3 retry attempts
const MAX_RETRY_JOB_AGE_HOURS = 2; // Do not revive stale requests beyond this age

let schedulerJob = null;
let isRetryCycleRunning = false;

function isRetryWindowExpired(job) {
    const createdAt = new Date(job.created_at);
    if (Number.isNaN(createdAt.getTime())) {
        return true;
    }

    const ageMs = Date.now() - createdAt.getTime();
    const maxAgeMs = MAX_RETRY_JOB_AGE_HOURS * 60 * 60 * 1000;
    return ageMs > maxAgeMs;
}

async function hasNewerOpenJob(job) {
    const { data, error } = await supabaseAdmin
        .from('jobs')
        .select('id')
        .eq('customer_id', job.customer_id)
        .neq('id', job.id)
        .in('status', ['pending', 'searching', 'no_technician_found'])
        .gt('created_at', job.created_at)
        .limit(1);

    if (error) {
        console.warn(`⚠️ [Scheduler] Failed superseded-check for ${job.id}:`, error.message);
        return false;
    }

    return (data || []).length > 0;
}

export function startJobRetryScheduler() {
    console.log('🕰 Starting Job Retry Scheduler...');

    schedulerJob = cron.schedule(RETRY_SCHEDULE, async () => {
        if (isRetryCycleRunning) {
            console.log('⏭️ [Scheduler] Previous retry cycle still running. Skipping this tick.');
            return;
        }

        isRetryCycleRunning = true;
        try {
            console.log('🔄 [Scheduler] Checking for jobs needing retry...');

            const now = new Date();

            // Find jobs that are ready for retry
            const { data: jobsToRetry, error } = await supabaseAdmin
                .from('jobs')
                .select('*')
                .eq('status', 'no_technician_found')
                .lte('next_search_at', now.toISOString())
                .lt('search_attempts', MAX_RETRIES);

            if (error) {
                console.error('❌ [Scheduler] Error fetching retry jobs:', error);
                return;
            }

            console.log(`📊 [Scheduler] Found ${jobsToRetry.length} jobs to retry`);

            // Retry each job
            for (const job of jobsToRetry) {
                try {
                    if (await hasActivePendingOffers(job.id)) {
                        const nowIso = new Date().toISOString();
                        await supabaseAdmin
                            .from('jobs')
                            .update({
                                status: 'searching',
                                next_search_at: null,
                                updated_at: nowIso
                            })
                            .eq('id', job.id)
                            .eq('status', 'no_technician_found')
                            .is('technician_id', null);

                        console.log(`ℹ️ [Scheduler] Restored job ${job.id} to searching because active offers still exist.`);
                        continue;
                    }

                    if (isRetryWindowExpired(job)) {
                        const nowIso = new Date().toISOString();
                        await supabaseAdmin
                            .from('jobs')
                            .update({
                                status: 'cancelled',
                                cancel_reason: 'retry_window_expired',
                                cancelled_at: nowIso,
                                cancelled_by: job.customer_id,
                                next_search_at: null,
                                updated_at: nowIso
                            })
                            .eq('id', job.id)
                            .in('status', ['no_technician_found', 'pending', 'searching']);

                        console.log(`🧹 [Scheduler] Cancelled stale retry job ${job.id} (retry window expired).`);
                        continue;
                    }

                    // Skip legacy stale jobs when a newer open job already exists
                    // for the same customer.
                    const superseded = await hasNewerOpenJob(job);
                    if (superseded) {
                        const nowIso = new Date().toISOString();
                        await supabaseAdmin
                            .from('jobs')
                            .update({
                                status: 'cancelled',
                                cancel_reason: 'superseded_by_newer_open_job',
                                cancelled_at: nowIso,
                                cancelled_by: job.customer_id,
                                next_search_at: null,
                                updated_at: nowIso
                            })
                            .eq('id', job.id)
                            .in('status', ['no_technician_found', 'pending', 'searching']);

                        console.log(`🧹 [Scheduler] Cancelled stale retry job ${job.id} (superseded).`);
                        continue;
                    }

                    console.log(`🔄 [Scheduler] Retrying job ${job.id} (attempt ${job.search_attempts + 1}/${MAX_RETRIES})...`);

                    // Reset status to 'pending' and start search again
                    const { error: updateError } = await supabaseAdmin
                        .from('jobs')
                        .update({
                            status: 'pending',
                            updated_at: new Date().toISOString()
                        })
                        .eq('id', job.id);

                    if (updateError) {
                        console.error(`❌ [Scheduler] Failed to reset job ${job.id}:`, updateError);
                        continue;
                    }

                    // Start search again
                    // Note: We need to pass the locations and service_id
                    await startJobSearch(job.id, job.lat, job.lng, job.service_id);

                    console.log(`✅ [Scheduler] Job ${job.id} search restarted`);

                } catch (jobError) {
                    console.error(`❌ [Scheduler] Error processing job ${job.id}:`, jobError);
                }
            }

            console.log(`✅ [Scheduler] Retry cycle complete. Processed ${jobsToRetry.length} jobs`);

        } catch (error) {
            console.error('❌ [Scheduler] Fatal error in retry cycle:', error);
        } finally {
            isRetryCycleRunning = false;
        }
    });

    console.log('✅ Job Retry Scheduler started');
}

export function stopJobRetryScheduler() {
    if (schedulerJob) {
        schedulerJob.stop();
        schedulerJob = null;
        console.log('🛑 Job Retry Scheduler stopped');
    }
}
