import { supabaseAdmin } from '../config/supabase.js';
import { recordNotificationLifecycle } from '../metrics/notificationMetrics.js';
import logger from '../utils/logger.js';

const VALID_STAGES = new Set(['sent', 'received', 'opened', 'actioned']);
const MAX_BATCH_SIZE = 50;
const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
let missingTableWarned = false;

function parseBoolean(value, fallback = true) {
  if (value == null) return fallback;
  const normalized = String(value).trim().toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  return fallback;
}

function toObject(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }
  return value;
}

function normalizeString(value, { maxLength = null, allowEmpty = false } = {}) {
  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();
  if (!allowEmpty && trimmed.length === 0) {
    return null;
  }

  if (maxLength && trimmed.length > maxLength) {
    return trimmed.slice(0, maxLength);
  }

  return trimmed;
}

function normalizeIsoDate(value) {
  const normalized = normalizeString(value);
  if (!normalized) return null;

  const parsed = new Date(normalized);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }
  return parsed.toISOString();
}

function normalizeUuid(value) {
  const normalized = normalizeString(value, { maxLength: 64 });
  if (!normalized) return null;
  return UUID_REGEX.test(normalized) ? normalized : null;
}

function isMissingTableError(error) {
  const code = String(error?.code || error?.dbCode || '');
  const message = String(error?.message || '');
  return code === '42P01' || code === 'PGRST205' || /notification_lifecycle_events/i.test(message);
}

function isDuplicateError(error) {
  return String(error?.code || error?.dbCode || '') === '23505';
}

function normalizeStage(value) {
  const stage = normalizeString(value, { maxLength: 24 });
  if (!stage) return null;
  return VALID_STAGES.has(stage) ? stage : null;
}

function normalizeLifecycleEvent(event = {}, fallback = {}) {
  const payload = toObject(event);

  const stage = normalizeStage(payload.stage ?? fallback.stage);
  const eventType = normalizeString(payload.eventType ?? payload.event_type ?? fallback.eventType, {
    maxLength: 120,
  });
  const requestId = normalizeString(payload.requestId ?? payload.request_id ?? fallback.requestId, {
    maxLength: 128,
  });
  const userId = normalizeString(payload.userId ?? payload.user_id ?? fallback.userId, {
    maxLength: 64,
  });
  const source =
    normalizeString(payload.source ?? fallback.source, {
      maxLength: 64,
    }) || 'unknown';

  if (!stage || !eventType || !requestId || !userId) {
    return null;
  }

  return {
    stage,
    eventType,
    requestId,
    userId,
    source,
    dedupeKey: normalizeString(payload.dedupeKey ?? payload.dedupe_key ?? fallback.dedupeKey, {
      maxLength: 255,
    }),
    notificationId: normalizeUuid(payload.notificationId ?? payload.notification_id ?? null),
    entityId: normalizeUuid(payload.entityId ?? payload.entity_id ?? null),
    occurredAt:
      normalizeIsoDate(payload.occurredAt ?? payload.occurred_at) || new Date().toISOString(),
    metadata: toObject(payload.metadata),
  };
}

function toLifecycleRow(event) {
  return {
    user_id: event.userId,
    notification_id: event.notificationId,
    event_stage: event.stage,
    event_type: event.eventType,
    request_id: event.requestId,
    dedupe_key: event.dedupeKey,
    entity_id: event.entityId,
    source: event.source,
    metadata: event.metadata,
    occurred_at: event.occurredAt,
  };
}

export async function trackNotificationLifecycleEvents(
  events,
  { fallbackUserId = null, fallbackSource = 'unknown', persist = true } = {}
) {
  const telemetryPersistenceEnabled = parseBoolean(
    process.env.FEATURE_NOTIFICATION_LIFECYCLE_TELEMETRY,
    true
  );

  const list = Array.isArray(events) ? events.slice(0, MAX_BATCH_SIZE) : [events];
  const normalizedEvents = list
    .map((event) =>
      normalizeLifecycleEvent(event, {
        userId: fallbackUserId,
        source: fallbackSource,
      })
    )
    .filter(Boolean);

  if (normalizedEvents.length === 0) {
    return { accepted: 0, persisted: 0, skipped: list.length };
  }

  for (const event of normalizedEvents) {
    recordNotificationLifecycle({
      stage: event.stage,
      eventType: event.eventType,
      source: event.source,
      outcome: 'accepted',
    });
  }

  if (!persist || !telemetryPersistenceEnabled) {
    return {
      accepted: normalizedEvents.length,
      persisted: 0,
      skipped: Math.max(0, list.length - normalizedEvents.length),
    };
  }

  const rows = normalizedEvents.map(toLifecycleRow);
  try {
    const { error } = await supabaseAdmin.from('notification_lifecycle_events').insert(rows);

    if (error) {
      throw error;
    }

    return {
      accepted: normalizedEvents.length,
      persisted: rows.length,
      skipped: Math.max(0, list.length - normalizedEvents.length),
    };
  } catch (error) {
    if (isDuplicateError(error)) {
      for (const event of normalizedEvents) {
        recordNotificationLifecycle({
          stage: event.stage,
          eventType: event.eventType,
          source: event.source,
          outcome: 'deduped',
        });
      }
      return {
        accepted: normalizedEvents.length,
        persisted: 0,
        skipped: Math.max(0, list.length - normalizedEvents.length),
      };
    }

    const outcome = isMissingTableError(error) ? 'storage_unavailable' : 'storage_error';

    for (const event of normalizedEvents) {
      recordNotificationLifecycle({
        stage: event.stage,
        eventType: event.eventType,
        source: event.source,
        outcome,
      });
    }

    if (isMissingTableError(error)) {
      if (!missingTableWarned) {
        logger.warn('⚠️ notification.telemetry_storage_unavailable', {
          message: error?.message || String(error),
        });
        missingTableWarned = true;
      }
      return {
        accepted: normalizedEvents.length,
        persisted: 0,
        skipped: Math.max(0, list.length - normalizedEvents.length),
      };
    }

    throw error;
  }
}
