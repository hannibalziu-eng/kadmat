import cron from 'node-cron';
import { supabaseAdmin } from '../config/supabase.js';
import logger from '../utils/logger.js';
import {
  recordNotificationCleanupDeleted,
  recordNotificationCleanupRun,
} from '../metrics/notificationMetrics.js';
import { recordSchedulerRun, recordSchedulerSkipped } from '../metrics/schedulerMetrics.js';

const CLEANUP_SCHEDULE = process.env.NOTIFICATION_CLEANUP_SCHEDULE || '15 * * * *';
const READ_RETENTION_DAYS = Number(process.env.NOTIFICATION_READ_RETENTION_DAYS || 30);
const ALL_RETENTION_DAYS = Number(process.env.NOTIFICATION_ALL_RETENTION_DAYS || 90);
const BATCH_SIZE = Number(process.env.NOTIFICATION_CLEANUP_BATCH_SIZE || 1000);
const MAX_BATCHES_PER_RUN = Number(process.env.NOTIFICATION_CLEANUP_MAX_BATCHES || 10);

let cleanupJob = null;
let isCleanupRunning = false;

function getCutoffIso(days) {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
}

async function fetchCandidateIds({ cutoffIso, readOnly }) {
  let query = supabaseAdmin
    .from('notifications')
    .select('id')
    .lt('created_at', cutoffIso)
    .order('created_at', { ascending: true })
    .limit(BATCH_SIZE);

  if (readOnly) {
    query = query.eq('is_read', true);
  }

  const { data, error } = await query;
  if (error) {
    throw new Error(`Failed to fetch notification candidates: ${error.message}`);
  }

  return (data || []).map((item) => item.id).filter(Boolean);
}

async function deleteByIds(ids) {
  if (!ids || ids.length === 0) return 0;

  const { error } = await supabaseAdmin.from('notifications').delete().in('id', ids);

  if (error) {
    throw new Error(`Failed to delete notifications: ${error.message}`);
  }

  return ids.length;
}

async function runPolicy({ policy, cutoffIso, readOnly }) {
  let deletedTotal = 0;

  for (let batch = 0; batch < MAX_BATCHES_PER_RUN; batch += 1) {
    const ids = await fetchCandidateIds({ cutoffIso, readOnly });
    if (ids.length === 0) break;

    const deleted = await deleteByIds(ids);
    deletedTotal += deleted;

    if (deleted < BATCH_SIZE) break;
  }

  if (deletedTotal > 0) {
    recordNotificationCleanupDeleted(policy, deletedTotal);
  }

  return deletedTotal;
}

export function startNotificationCleanupScheduler() {
  logger.info('🧹 Starting Notification Cleanup Scheduler...');

  cleanupJob = cron.schedule(CLEANUP_SCHEDULE, async () => {
    if (isCleanupRunning) {
      logger.info('⏭️ [NotificationCleanup] Previous cycle still running. Skipping tick.');
      recordSchedulerSkipped('notification_cleanup', 'overlap');
      return;
    }

    const cycleStartMs = Date.now();
    let cycleResult = 'success';
    isCleanupRunning = true;
    try {
      const readCutoff = getCutoffIso(READ_RETENTION_DAYS);
      const allCutoff = getCutoffIso(ALL_RETENTION_DAYS);

      const deletedRead = await runPolicy({
        policy: 'read_30d',
        cutoffIso: readCutoff,
        readOnly: true,
      });

      const deletedAll = await runPolicy({
        policy: 'all_90d',
        cutoffIso: allCutoff,
        readOnly: false,
      });

      const totalDeleted = deletedRead + deletedAll;
      if (totalDeleted > 0) {
        logger.info(
          `🧹 [NotificationCleanup] Deleted ${totalDeleted} rows (read>${READ_RETENTION_DAYS}d=${deletedRead}, all>${ALL_RETENTION_DAYS}d=${deletedAll})`
        );
      }
      recordNotificationCleanupRun('success');
    } catch (error) {
      logger.error('❌ [NotificationCleanup] Failed cleanup cycle:', error?.message || error);
      recordNotificationCleanupRun('error');
      cycleResult = 'error';
    } finally {
      isCleanupRunning = false;
      recordSchedulerRun({
        scheduler: 'notification_cleanup',
        result: cycleResult,
        durationMs: Date.now() - cycleStartMs,
      });
    }
  });

  logger.info(`✅ Notification Cleanup Scheduler started (${CLEANUP_SCHEDULE})`);
}

export function stopNotificationCleanupScheduler() {
  if (cleanupJob) {
    cleanupJob.stop();
    cleanupJob = null;
    logger.info('🛑 Notification Cleanup Scheduler stopped');
  }
}
