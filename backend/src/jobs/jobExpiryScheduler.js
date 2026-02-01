/**
 * Job Expiry Timer Service
 * Handles automatic job expiry and technician timeout
 */

import cron from 'node-cron';
import { supabaseAdmin } from '../config/supabase.js';
import { sendPushNotification } from '../services/fcmService.js';
import { startJobSearch } from '../services/jobSearchService.js';

// Configuration
const JOB_EXPIRY_MINUTES = 30;       // Job expires if no technician found in 30 mins
const START_WORK_TIMEOUT_MINUTES = 30; // Technician has 30 mins to start work after accepting

// Run every minute
const CHECK_SCHEDULE = '* * * * *';

let schedulerJob = null;

/**
 * Start the job expiry scheduler
 */
export function startJobExpiryScheduler() {
    console.log('⏱️  Starting Job Expiry Scheduler...');

    schedulerJob = cron.schedule(CHECK_SCHEDULE, async () => {
        try {
            // Check both types of timeouts
            await checkJobExpiry();
            await checkStartWorkTimeout();
        } catch (error) {
            console.error('❌ [ExpiryScheduler] Fatal error:', error);
        }
    });

    console.log('✅ Job Expiry Scheduler started');
}

/**
 * Check for jobs that should expire (no technician found after 30 mins)
 */
async function checkJobExpiry() {
    const cutoffTime = new Date(Date.now() - JOB_EXPIRY_MINUTES * 60 * 1000);

    // Find jobs that are still pending/searching and old enough
    const { data: expiredJobs, error } = await supabaseAdmin
        .from('jobs')
        .select('id, customer_id, status, created_at, search_attempts')
        .in('status', ['pending', 'searching'])
        .lt('created_at', cutoffTime.toISOString())
        .is('technician_id', null);

    if (error) {
        console.error('❌ [ExpiryScheduler] Error fetching expired jobs:', error);
        return;
    }

    if (!expiredJobs || expiredJobs.length === 0) {
        return; // No expired jobs
    }

    console.log(`⏱️  [ExpiryScheduler] Processing ${expiredJobs.length} expired jobs...`);

    for (const job of expiredJobs) {
        try {
            // Check if we should retry or give up
            const searchAttempts = job.search_attempts || 0;

            if (searchAttempts < 3) {
                // Schedule retry
                const nextRetryTime = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

                await supabaseAdmin
                    .from('jobs')
                    .update({
                        status: 'no_technician_found',
                        search_attempts: searchAttempts + 1,
                        last_search_at: new Date().toISOString(),
                        next_search_at: nextRetryTime.toISOString(),
                        updated_at: new Date().toISOString()
                    })
                    .eq('id', job.id);

                // Notify customer
                await supabaseAdmin.from('notifications').insert({
                    user_id: job.customer_id,
                    type: 'no_technician',
                    title: 'لم يتم العثور على فني 😔',
                    body: `لم يتم العثور على فني متاح. سنحاول مجدداً قريباً.`,
                    data: { job_id: job.id },
                    is_read: false
                });

                // Send push notification
                await sendPushNotification(job.customer_id, {
                    title: 'لم يتم العثور على فني 😔',
                    body: 'سنحاول مجدداً قريباً',
                    data: { type: 'no_technician', job_id: job.id }
                });

                console.log(`⏱️  [Job ${job.id}] Marked for retry (attempt ${searchAttempts + 1}/3)`);
            } else {
                // Give up after 3 attempts - mark as expired
                await supabaseAdmin
                    .from('jobs')
                    .update({
                        status: 'expired',
                        expired_at: new Date().toISOString(),
                        updated_at: new Date().toISOString()
                    })
                    .eq('id', job.id);

                // Notify customer
                await supabaseAdmin.from('notifications').insert({
                    user_id: job.customer_id,
                    type: 'job_expired',
                    title: 'انتهت صلاحية الطلب',
                    body: 'لم يتم العثور على فني. يمكنك إنشاء طلب جديد.',
                    data: { job_id: job.id },
                    is_read: false
                });

                await sendPushNotification(job.customer_id, {
                    title: 'انتهت صلاحية الطلب',
                    body: 'يمكنك إنشاء طلب جديد',
                    data: { type: 'job_expired', job_id: job.id }
                });

                console.log(`💀 [Job ${job.id}] Expired after 3 attempts`);
            }
        } catch (jobError) {
            console.error(`❌ [ExpiryScheduler] Error processing job ${job.id}:`, jobError);
        }
    }
}

/**
 * Check for jobs where technician accepted but didn't start work within timeout
 */
async function checkStartWorkTimeout() {
    const cutoffTime = new Date(Date.now() - START_WORK_TIMEOUT_MINUTES * 60 * 1000);

    // Find jobs that are accepted but old enough (technician didn't start)
    const { data: timeoutJobs, error } = await supabaseAdmin
        .from('jobs')
        .select('id, customer_id, technician_id, status, accepted_at')
        .eq('status', 'accepted')
        .lt('accepted_at', cutoffTime.toISOString());

    if (error) {
        console.error('❌ [ExpiryScheduler] Error fetching timeout jobs:', error);
        return;
    }

    if (!timeoutJobs || timeoutJobs.length === 0) {
        return;
    }

    console.log(`⏱️  [ExpiryScheduler] Processing ${timeoutJobs.length} start-work timeouts...`);

    for (const job of timeoutJobs) {
        try {
            // Penalize technician
            // Penalize technician
            const { error: penaltyError } = await supabaseAdmin.rpc('increment_technician_penalty', {
                p_technician_id: job.technician_id,
                p_penalty_type: 'no_start'
            });

            if (penaltyError) {
                // If RPC doesn't exist, update directly
                console.log(`⚠️  [Job ${job.id}] Penalty RPC error or not available, skipping penalty:`, penaltyError.message);
            }

            // Revert job to pending
            await supabaseAdmin
                .from('jobs')
                .update({
                    status: 'pending',
                    technician_id: null,
                    accepted_at: null,
                    updated_at: new Date().toISOString()
                })
                .eq('id', job.id);

            // Notify customer
            await supabaseAdmin.from('notifications').insert({
                user_id: job.customer_id,
                type: 'technician_timeout',
                title: 'الفني لم يستجب ⏱️',
                body: 'جاري البحث عن فني آخر...',
                data: { job_id: job.id },
                is_read: false
            });

            await sendPushNotification(job.customer_id, {
                title: 'الفني لم يستجب ⏱️',
                body: 'جاري البحث عن فني آخر...',
                data: { type: 'technician_timeout', job_id: job.id }
            });

            // Notify technician about penalty
            await supabaseAdmin.from('notifications').insert({
                user_id: job.technician_id,
                type: 'penalty_warning',
                title: 'تنبيه: عدم بدء العمل',
                body: 'تم إلغاء تعيينك للطلب بسبب عدم بدء العمل في الوقت المحدد.',
                data: { job_id: job.id },
                is_read: false
            });

            // Restart job search
            const { data: jobDetails } = await supabaseAdmin
                .from('jobs')
                .select('lat, lng, service_id')
                .eq('id', job.id)
                .single();

            if (jobDetails) {
                await startJobSearch(job.id, jobDetails.lat, jobDetails.lng, jobDetails.service_id);
            }

            console.log(`🔄 [Job ${job.id}] Reset to pending - technician timeout`);

        } catch (jobError) {
            console.error(`❌ [ExpiryScheduler] Error processing job ${job.id}:`, jobError);
        }
    }
}

/**
 * Stop the scheduler
 */
export function stopJobExpiryScheduler() {
    if (schedulerJob) {
        schedulerJob.stop();
        schedulerJob = null;
        console.log('🛑 Job Expiry Scheduler stopped');
    }
}
