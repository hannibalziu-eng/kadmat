/**
 * Job Retry Scheduler
 * Automatically retries search for jobs with no technicians found
 */

import cron from 'node-cron';
import { supabaseAdmin } from '../config/supabase.js';
import { startJobSearch } from '../services/jobSearchService.js';

// Run every hour at minute 0
const RETRY_SCHEDULE = '0 * * * *'; // 00:00, 01:00, 02:00, etc.
const MAX_RETRIES = 3; // Max 3 retry attempts

let schedulerJob = null;

export function startJobRetryScheduler() {
    console.log('🕰 Starting Job Retry Scheduler...');

    schedulerJob = cron.schedule(RETRY_SCHEDULE, async () => {
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
