import cron from 'node-cron';
import { supabaseAdmin } from '../config/supabase.js';
import { notifyUser } from '../services/notificationOrchestrator.js';
import { featureFlags } from '../config/featureFlags.js';
import { recordStaleLockRecovery } from '../metrics/jobFlowMetrics.js';
import { recordSchedulerRun, recordSchedulerSkipped } from '../metrics/schedulerMetrics.js';
import logger from '../utils/logger.js';

const LOCKED_STATUSES = ['on_the_way', 'arrived', 'in_progress', 'pending_confirm'];
const SCHEDULE = '0 * * * *'; // Hourly

let recoveryJob = null;

export function startStaleLockRecoveryScheduler() {
  if (!featureFlags.staleLockRecovery) {
    logger.info('⏭️  Stale Lock Recovery Scheduler disabled by feature flag');
    recordSchedulerSkipped('stale_lock_recovery', 'feature_disabled');
    return;
  }

  logger.info(
    `🧯 Starting Stale Lock Recovery Scheduler (every hour, threshold=${featureFlags.staleLockHours}h)...`
  );

  recoveryJob = cron.schedule(SCHEDULE, async () => {
    const cycleStartMs = Date.now();
    let cycleResult = 'success';
    try {
      await recoverStaleLocks();
    } catch (error) {
      logger.error('❌ [StaleLockRecovery] Fatal scheduler error:', error);
      recordStaleLockRecovery('fatal_error', 'unknown');
      cycleResult = 'fatal_error';
    } finally {
      recordSchedulerRun({
        scheduler: 'stale_lock_recovery',
        result: cycleResult,
        durationMs: Date.now() - cycleStartMs,
      });
    }
  });

  logger.info('✅ Stale Lock Recovery Scheduler started');
}

export function stopStaleLockRecoveryScheduler() {
  if (recoveryJob) {
    recoveryJob.stop();
    recoveryJob = null;
    logger.info('🛑 Stale Lock Recovery Scheduler stopped');
  }
}

async function recoverStaleLocks() {
  const cutoff = new Date(Date.now() - featureFlags.staleLockHours * 60 * 60 * 1000).toISOString();
  const nowIso = new Date().toISOString();

  const { data: staleJobs, error } = await supabaseAdmin
    .from('jobs')
    .select('id, customer_id, technician_id, status, metadata, updated_at')
    .in('status', LOCKED_STATUSES)
    .lt('updated_at', cutoff);

  if (error) {
    logger.error('❌ [StaleLockRecovery] Failed fetching stale locks:', error);
    recordStaleLockRecovery('fetch_error', 'unknown');
    return;
  }

  if (!staleJobs || staleJobs.length === 0) {
    return;
  }

  logger.info(`🧯 [StaleLockRecovery] Found ${staleJobs.length} stale locked jobs`);

  for (const job of staleJobs) {
    try {
      const metadata = job.metadata && typeof job.metadata === 'object' ? job.metadata : {};

      const { data: updatedJob, error: updateError } = await supabaseAdmin
        .from('jobs')
        .update({
          status: 'cancelled',
          cancelled_at: nowIso,
          updated_at: nowIso,
          metadata: {
            ...metadata,
            stale_lock_recovered: true,
            stale_lock_recovered_at: nowIso,
            stale_lock_previous_status: job.status,
            cancellation_reason: 'stale_lock_recovery',
          },
        })
        .eq('id', job.id)
        .in('status', LOCKED_STATUSES)
        .select('id, status')
        .maybeSingle();

      if (updateError) {
        logger.error(`❌ [StaleLockRecovery] Update failed for ${job.id}:`, updateError);
        recordStaleLockRecovery('update_error', job.status);
        continue;
      }

      if (!updatedJob) {
        recordStaleLockRecovery('race_skipped', job.status);
        continue;
      }

      recordStaleLockRecovery('cancelled', job.status);

      const sharedData = {
        job_id: job.id,
        recovery_type: 'stale_lock',
        previous_status: job.status,
      };

      if (job.customer_id) {
        await notifyUser({
          userId: job.customer_id,
          type: 'stale_lock_recovered',
          title: 'تم إنهاء الطلب تلقائياً',
          body: 'تم رصد تعطل في الطلب وتم إنهاؤه تلقائياً. يرجى التواصل مع الدعم عند الحاجة.',
          data: sharedData,
          entityType: 'job',
          entityId: job.id,
          dedupeKey: `stale_lock_recovered_customer:${job.id}:${job.customer_id}`,
        });
      }

      if (job.technician_id) {
        await notifyUser({
          userId: job.technician_id,
          type: 'stale_lock_recovered',
          title: 'تم فك القفل عن حسابك',
          body: 'تم رصد تعطل في الطلب وتم إنهاؤه تلقائياً لإتاحة استقبال طلبات جديدة.',
          data: sharedData,
          entityType: 'job',
          entityId: job.id,
          dedupeKey: `stale_lock_recovered_technician:${job.id}:${job.technician_id}`,
        });
      }
    } catch (jobError) {
      logger.error(`❌ [StaleLockRecovery] Error processing job ${job.id}:`, jobError);
      recordStaleLockRecovery('process_error', job.status);
    }
  }
}
