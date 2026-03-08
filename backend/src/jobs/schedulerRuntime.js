import { startJobRetryScheduler, stopJobRetryScheduler } from './jobRetryScheduler.js';
import { startJobExpiryScheduler, stopJobExpiryScheduler } from './jobExpiryScheduler.js';
import {
  startNotificationCleanupScheduler,
  stopNotificationCleanupScheduler,
} from './notificationCleanupScheduler.js';
import {
  startStaleLockRecoveryScheduler,
  stopStaleLockRecoveryScheduler,
} from './staleLockRecoveryScheduler.js';
import { initializeFirebase } from '../services/fcmService.js';

let started = false;

function parseBoolean(value, fallback = false) {
  if (value == null) return fallback;
  const normalized = String(value).trim().toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  return fallback;
}

export function shouldRunSchedulersInApi() {
  // Safe default is always false to avoid duplicate cron execution
  // when API runs in multiple processes (cluster/PM2).
  return parseBoolean(process.env.RUN_SCHEDULERS_IN_API, false);
}

export function startSchedulerRuntime({ includeFirebase = true } = {}) {
  if (started) return;

  if (includeFirebase) {
    initializeFirebase();
  }

  startJobRetryScheduler();
  startJobExpiryScheduler();
  startNotificationCleanupScheduler();
  startStaleLockRecoveryScheduler();

  started = true;
}

export function stopSchedulerRuntime() {
  if (!started) return;

  stopJobRetryScheduler();
  stopJobExpiryScheduler();
  stopNotificationCleanupScheduler();
  stopStaleLockRecoveryScheduler();

  started = false;
}
