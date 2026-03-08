import Joi from 'joi';

const MIN_TTL_SECONDS = 30;
const MAX_TTL_SECONDS = 7 * 24 * 60 * 60;
const DEFAULT_TTL_SECONDS_HIGH = 5 * 60;
const DEFAULT_TTL_SECONDS_MEDIUM = 30 * 60;
const DEFAULT_TTL_SECONDS_LOW = 6 * 60 * 60;

const STATUS_EVENT_TYPES = new Set([
  'new_job_offer',
  'new_offer',
  'offer_accepted',
  'job_accepted',
  'price_request',
  'price_pending',
  'price_confirmed',
  'technician_arrived',
  'work_started',
  'completion_request',
  'job_cancelled_by_customer',
  'job_cancelled_by_technician',
  'job_completed',
  'technician_timeout',
  'stale_lock_recovered',
]);

const notificationEventSchema = Joi.object({
  event_type: Joi.string().trim().min(1).required(),
  order_id: Joi.string().trim().allow(null),
  deep_link: Joi.string().trim().max(512).allow(null),
  dedupe_key: Joi.string().trim().max(255).allow(null),
  collapse_key: Joi.string().trim().max(255).allow(null),
  channel_id: Joi.string().trim().max(64).allow(null),
  priority: Joi.number().integer().min(1).max(5).required(),
  ttl_seconds: Joi.number().integer().min(MIN_TTL_SECONDS).max(MAX_TTL_SECONDS).required(),
});

function toObject(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }
  return value;
}

function normalizeString(value) {
  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function toFiniteNumber(value) {
  if (value === null || value === undefined || value === '') {
    return null;
  }

  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : null;
}

function resolveOrderId(data, explicitEntityId) {
  const entityId = normalizeString(explicitEntityId);
  if (entityId) {
    return entityId;
  }

  const payload = toObject(data);
  return (
    normalizeString(payload.order_id) ||
    normalizeString(payload.orderId) ||
    normalizeString(payload.job_id) ||
    normalizeString(payload.jobId) ||
    normalizeString(payload.entity_id) ||
    normalizeString(payload.entityId) ||
    null
  );
}

function resolveDeepLink(data, explicitDeepLink) {
  const direct = normalizeString(explicitDeepLink);
  if (direct) {
    return direct;
  }

  const payload = toObject(data);
  return (
    normalizeString(payload.deep_link) ||
    normalizeString(payload.deepLink) ||
    normalizeString(payload.link) ||
    normalizeString(payload.route) ||
    null
  );
}

function resolvePriority(value, fallbackValue = 3) {
  const candidate = Number.isFinite(Number(value)) ? Number(value) : Number(fallbackValue);

  if (!Number.isFinite(candidate)) {
    return 3;
  }

  return Math.max(1, Math.min(5, Math.trunc(candidate)));
}

function resolveTtlSeconds({ ttlSeconds, defaultTtlSeconds, data, priority }) {
  const payload = toObject(data);
  const candidate =
    toFiniteNumber(ttlSeconds) ??
    toFiniteNumber(defaultTtlSeconds) ??
    toFiniteNumber(payload.ttl_seconds);

  if (candidate !== null) {
    return Math.trunc(candidate);
  }

  if (priority >= 4) {
    return DEFAULT_TTL_SECONDS_HIGH;
  }

  if (priority === 3) {
    return DEFAULT_TTL_SECONDS_MEDIUM;
  }

  return DEFAULT_TTL_SECONDS_LOW;
}

function resolveChannelId({ channelId, defaultChannelId, data, priority }) {
  const payload = toObject(data);
  const explicit =
    normalizeString(channelId) ||
    normalizeString(defaultChannelId) ||
    normalizeString(payload.channel_id) ||
    normalizeString(payload.channelId);

  if (explicit) {
    return explicit;
  }

  if (priority >= 4) {
    return 'critical_alerts';
  }

  if (priority === 3) {
    return 'important_updates';
  }

  return 'standard_notifications';
}

function resolveCollapseKey({ collapseKey, collapseScope, data, eventType, orderId }) {
  const payload = toObject(data);
  const explicit =
    normalizeString(collapseKey) ||
    normalizeString(payload.collapse_key) ||
    normalizeString(payload.collapseKey);

  if (explicit) {
    return explicit;
  }

  if (!orderId) {
    return null;
  }

  const normalizedScope = normalizeString(collapseScope) || 'auto';
  if (normalizedScope === 'none') {
    return null;
  }
  if (normalizedScope === 'order_status') {
    return `order_${orderId}_status`;
  }
  if (normalizedScope === 'order') {
    return `order_${orderId}`;
  }
  if (normalizedScope === 'event_order') {
    return `order_${orderId}_${String(eventType || '').trim() || 'event'}`;
  }

  if (STATUS_EVENT_TYPES.has(String(eventType || '').trim())) {
    return `order_${orderId}_status`;
  }

  return `order_${orderId}`;
}

export function buildNotificationEventContract({
  eventType,
  data,
  entityId,
  dedupeKey,
  priority,
  ttlSeconds,
  collapseKey,
  collapseScope,
  deepLink,
  channelId,
  defaultTtlSeconds,
  defaultChannelId,
} = {}) {
  const safeEventType = normalizeString(eventType) || '';
  const resolvedPriority = resolvePriority(priority, 3);
  const resolvedOrderId = resolveOrderId(data, entityId);

  return {
    event_type: safeEventType,
    order_id: resolvedOrderId,
    deep_link: resolveDeepLink(data, deepLink),
    dedupe_key: normalizeString(dedupeKey),
    collapse_key: resolveCollapseKey({
      collapseKey,
      collapseScope,
      data,
      eventType: safeEventType,
      orderId: resolvedOrderId,
    }),
    channel_id: resolveChannelId({
      channelId,
      defaultChannelId,
      data,
      priority: resolvedPriority,
    }),
    priority: resolvedPriority,
    ttl_seconds: resolveTtlSeconds({
      ttlSeconds,
      defaultTtlSeconds,
      data,
      priority: resolvedPriority,
    }),
  };
}

export function validateNotificationEventContract(contract) {
  const { value, error } = notificationEventSchema.validate(contract, {
    abortEarly: false,
    stripUnknown: true,
  });

  if (!error) {
    return value;
  }

  const err = new Error('Notification event contract validation failed');
  err.code = 'NOTIFICATION_EVENT_CONTRACT_INVALID';
  err.details = error.details.map((item) => ({
    path: item.path.join('.'),
    message: item.message,
  }));
  throw err;
}

export function buildAndValidateNotificationEvent(input = {}) {
  const contract = buildNotificationEventContract(input);
  return validateNotificationEventContract(contract);
}

export const notificationEventContractBounds = {
  MIN_TTL_SECONDS,
  MAX_TTL_SECONDS,
  DEFAULT_TTL_SECONDS_HIGH,
  DEFAULT_TTL_SECONDS_MEDIUM,
  DEFAULT_TTL_SECONDS_LOW,
};
