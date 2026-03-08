function toFiniteInt(value) {
  if (value === null || value === undefined || value === '') {
    return null;
  }

  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return null;
  return Math.trunc(numeric);
}

function normalizeString(value) {
  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeBoolean(value, fallback) {
  if (typeof value === 'boolean') {
    return value;
  }
  return fallback;
}

export const DEFAULT_NOTIFICATION_EVENT_POLICY = {
  ttlSeconds: null,
  pushChannelId: null,
  collapseScope: 'auto',
  autoDedupe: true,
};

export const NOTIFICATION_EVENT_POLICY_REGISTRY = {
  new_job_offer: {
    ttlSeconds: 300,
    pushChannelId: 'critical_alerts',
    collapseScope: 'order_status',
    autoDedupe: true,
  },
  new_offer: {
    ttlSeconds: 900,
    pushChannelId: 'important_updates',
    collapseScope: 'order_status',
    autoDedupe: true,
  },
  offer_accepted: {
    ttlSeconds: 300,
    pushChannelId: 'critical_alerts',
    collapseScope: 'order_status',
    autoDedupe: true,
  },
  price_request: {
    ttlSeconds: 900,
    pushChannelId: 'important_updates',
    collapseScope: 'order_status',
    autoDedupe: true,
  },
  price_confirmed: {
    ttlSeconds: 900,
    pushChannelId: 'important_updates',
    collapseScope: 'order_status',
    autoDedupe: true,
  },
  technician_arrived: {
    ttlSeconds: 300,
    pushChannelId: 'critical_alerts',
    collapseScope: 'order_status',
    autoDedupe: true,
  },
  work_started: {
    ttlSeconds: 900,
    pushChannelId: 'important_updates',
    collapseScope: 'order_status',
    autoDedupe: true,
  },
  completion_request: {
    ttlSeconds: 1200,
    pushChannelId: 'critical_alerts',
    collapseScope: 'order_status',
    autoDedupe: true,
  },
  job_cancelled_by_customer: {
    ttlSeconds: 1200,
    pushChannelId: 'critical_alerts',
    collapseScope: 'order_status',
    autoDedupe: true,
  },
  job_cancelled_by_technician: {
    ttlSeconds: 1200,
    pushChannelId: 'critical_alerts',
    collapseScope: 'order_status',
    autoDedupe: true,
  },
  job_completed: {
    ttlSeconds: 3600,
    pushChannelId: 'important_updates',
    collapseScope: 'order',
    autoDedupe: true,
  },
  no_technician: {
    ttlSeconds: 3600,
    pushChannelId: 'important_updates',
    collapseScope: 'order',
    autoDedupe: true,
  },
  technician_timeout: {
    ttlSeconds: 600,
    pushChannelId: 'critical_alerts',
    collapseScope: 'order_status',
    autoDedupe: true,
  },
  penalty_warning: {
    ttlSeconds: 3600,
    pushChannelId: 'important_updates',
    collapseScope: 'order',
    autoDedupe: true,
  },
  stale_lock_recovered: {
    ttlSeconds: 3600,
    pushChannelId: 'important_updates',
    collapseScope: 'order',
    autoDedupe: true,
  },
};

export function resolveNotificationEventPolicy(eventType, overrides = {}) {
  const safeType = String(eventType || '').trim();
  const registry =
    NOTIFICATION_EVENT_POLICY_REGISTRY[safeType] || DEFAULT_NOTIFICATION_EVENT_POLICY;

  const ttlCandidate = toFiniteInt(overrides.ttlSeconds);
  const registryTtl = toFiniteInt(registry.ttlSeconds);

  const overrideChannel = normalizeString(overrides.pushChannelId);
  const registryChannel = normalizeString(registry.pushChannelId);

  const overrideCollapse = normalizeString(overrides.collapseScope);
  const registryCollapse = normalizeString(registry.collapseScope);

  return {
    ttlSeconds: ttlCandidate ?? registryTtl ?? null,
    pushChannelId: overrideChannel || registryChannel || null,
    collapseScope: overrideCollapse || registryCollapse || 'auto',
    autoDedupe: normalizeBoolean(overrides.autoDedupe, normalizeBoolean(registry.autoDedupe, true)),
  };
}

export function resolveNotificationDedupeKey({
  explicitDedupeKey,
  eventType,
  orderId,
  userId,
  autoDedupe = true,
} = {}) {
  const explicit = normalizeString(explicitDedupeKey);
  if (explicit) {
    return explicit;
  }

  if (!autoDedupe) {
    return null;
  }

  const safeEventType = normalizeString(eventType) || 'notification';
  const safeOrderId = normalizeString(orderId);
  const safeUserId = normalizeString(userId);

  if (safeOrderId && safeUserId) {
    return `${safeEventType}:${safeOrderId}:${safeUserId}`;
  }

  if (safeOrderId) {
    return `${safeEventType}:${safeOrderId}`;
  }

  if (safeUserId) {
    return `${safeEventType}:user:${safeUserId}`;
  }

  return `${safeEventType}:global`;
}
