import { client, register } from '../config/monitoring.js';

function getOrCreateCounter(name, help, labelNames = []) {
  const existing = register.getSingleMetric(name);
  if (existing) return existing;

  return new client.Counter({
    name,
    help,
    labelNames,
    registers: [register],
  });
}

const notificationInboxEventsTotal = getOrCreateCounter(
  'notification_inbox_events_total',
  'Notification inbox events by type and outcome',
  ['type', 'outcome']
);

const notificationPushEventsTotal = getOrCreateCounter(
  'notification_push_events_total',
  'Notification push events by type and outcome',
  ['type', 'outcome']
);

const notificationAudienceMismatchTotal = getOrCreateCounter(
  'notification_audience_mismatch_total',
  'Notification audience-role mismatch events',
  ['audience_role', 'strict']
);

const notificationCleanupRunsTotal = getOrCreateCounter(
  'notification_cleanup_runs_total',
  'Notification cleanup scheduler runs',
  ['result']
);

const notificationCleanupDeletedTotal = getOrCreateCounter(
  'notification_cleanup_deleted_total',
  'Deleted notifications by retention policy',
  ['policy']
);

const notificationLifecycleEventsTotal = getOrCreateCounter(
  'notification_lifecycle_events_total',
  'Notification lifecycle telemetry events',
  ['stage', 'event_type', 'source', 'outcome']
);

export function recordNotificationInbox(type, { inserted = 0, deduped = 0, skipped = false } = {}) {
  const safeType = type || 'unknown';

  if (skipped) {
    notificationInboxEventsTotal.labels(safeType, 'skipped').inc(1);
    return;
  }

  if (inserted > 0) {
    notificationInboxEventsTotal.labels(safeType, 'inserted').inc(inserted);
  }

  if (deduped > 0) {
    notificationInboxEventsTotal.labels(safeType, 'deduped').inc(deduped);
  }
}

export function recordNotificationPush(type, pushResult) {
  const safeType = type || 'unknown';
  const result = pushResult || {};

  if (result.reason === 'push_channel_disabled') {
    notificationPushEventsTotal.labels(safeType, 'skipped').inc(1);
    return;
  }

  if (result.success === true) {
    const sentCount = Number.isFinite(Number(result.sent)) ? Math.max(1, Number(result.sent)) : 1;
    notificationPushEventsTotal.labels(safeType, 'sent').inc(sentCount);

    const failedCount = Number.isFinite(Number(result.failed))
      ? Math.max(0, Number(result.failed))
      : 0;
    if (failedCount > 0) {
      notificationPushEventsTotal.labels(safeType, 'failed').inc(failedCount);
    }
    return;
  }

  notificationPushEventsTotal.labels(safeType, 'failed').inc(1);
}

export function recordNotificationAudienceMismatch(audienceRole, strict, count = 1) {
  notificationAudienceMismatchTotal
    .labels(audienceRole || 'unknown', strict ? 'true' : 'false')
    .inc(Math.max(1, Number(count) || 1));
}

export function recordNotificationCleanupRun(result) {
  notificationCleanupRunsTotal.labels(result || 'unknown').inc(1);
}

export function recordNotificationCleanupDeleted(policy, count) {
  const numeric = Number(count);
  if (!Number.isFinite(numeric) || numeric <= 0) return;
  notificationCleanupDeletedTotal.labels(policy || 'unknown').inc(numeric);
}

export function recordNotificationLifecycle({
  stage,
  eventType,
  source,
  outcome = 'accepted',
  count = 1,
} = {}) {
  const numeric = Number(count);
  if (!Number.isFinite(numeric) || numeric <= 0) return;

  notificationLifecycleEventsTotal
    .labels(
      String(stage || 'unknown'),
      String(eventType || 'unknown'),
      String(source || 'unknown'),
      String(outcome || 'unknown')
    )
    .inc(numeric);
}
