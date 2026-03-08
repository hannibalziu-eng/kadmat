export const AUDIENCE_ROLES = ['customer', 'technician', 'admin', 'all'];
export const NOTIFICATION_CATEGORIES = ['job', 'offer', 'payment', 'message', 'system'];
export const NOTIFICATION_CHANNELS = ['inbox', 'push', 'in_app'];

export const DEFAULT_NOTIFICATION_CHANNELS = ['inbox'];
export const DEFAULT_NOTIFICATION_PRIORITY = 3;

export const NOTIFICATION_TYPE_REGISTRY = {
  new_job_offer: {
    audienceRole: 'technician',
    category: 'job',
    channels: ['inbox', 'push', 'in_app'],
    priority: 4,
    entityType: 'job',
  },
  new_offer: {
    audienceRole: 'customer',
    category: 'offer',
    channels: ['inbox', 'push', 'in_app'],
    priority: 4,
    entityType: 'job',
  },
  offer_accepted: {
    audienceRole: 'technician',
    category: 'message',
    channels: ['inbox', 'push', 'in_app'],
    priority: 5,
    entityType: 'job',
  },
  price_request: {
    audienceRole: 'customer',
    category: 'offer',
    channels: ['inbox', 'push', 'in_app'],
    priority: 4,
    entityType: 'job',
  },
  price_confirmed: {
    audienceRole: 'technician',
    category: 'message',
    channels: ['inbox', 'push', 'in_app'],
    priority: 4,
    entityType: 'job',
  },
  technician_arrived: {
    audienceRole: 'customer',
    category: 'message',
    channels: ['inbox', 'push', 'in_app'],
    priority: 4,
    entityType: 'job',
  },
  work_started: {
    audienceRole: 'customer',
    category: 'message',
    channels: ['inbox', 'in_app'],
    priority: 3,
    entityType: 'job',
  },
  completion_request: {
    audienceRole: 'customer',
    category: 'message',
    channels: ['inbox', 'push', 'in_app'],
    priority: 4,
    entityType: 'job',
  },
  job_cancelled_by_customer: {
    audienceRole: 'technician',
    category: 'message',
    channels: ['inbox', 'push', 'in_app'],
    priority: 4,
    entityType: 'job',
  },
  job_cancelled_by_technician: {
    audienceRole: 'customer',
    category: 'message',
    channels: ['inbox', 'push', 'in_app'],
    priority: 4,
    entityType: 'job',
  },
  job_completed: {
    audienceRole: 'technician',
    category: 'payment',
    channels: ['inbox', 'in_app'],
    priority: 4,
    entityType: 'job',
  },
  no_technician: {
    audienceRole: 'customer',
    category: 'job',
    channels: ['inbox', 'in_app'],
    priority: 3,
    entityType: 'job',
  },
  technician_timeout: {
    audienceRole: 'customer',
    category: 'message',
    channels: ['inbox', 'push', 'in_app'],
    priority: 4,
    entityType: 'job',
  },
  penalty_warning: {
    audienceRole: 'technician',
    category: 'system',
    channels: ['inbox', 'in_app'],
    priority: 4,
    entityType: 'job',
  },
  stale_lock_recovered: {
    audienceRole: 'all',
    category: 'system',
    channels: ['inbox', 'push', 'in_app'],
    priority: 4,
    entityType: 'job',
  },

  // Legacy/compatibility types
  new_job: {
    audienceRole: 'technician',
    category: 'job',
    channels: ['inbox', 'in_app'],
    priority: 4,
    entityType: 'job',
  },
  job_accepted: {
    audienceRole: 'customer',
    category: 'message',
    channels: ['inbox', 'push', 'in_app'],
    priority: 4,
    entityType: 'job',
  },
  price_set: {
    audienceRole: 'customer',
    category: 'offer',
    channels: ['inbox', 'push', 'in_app'],
    priority: 4,
    entityType: 'job',
  },
  price_pending: {
    audienceRole: 'customer',
    category: 'offer',
    channels: ['inbox', 'push', 'in_app'],
    priority: 4,
    entityType: 'job',
  },
  completed: {
    audienceRole: 'customer',
    category: 'payment',
    channels: ['inbox', 'in_app'],
    priority: 3,
    entityType: 'job',
  },
  warning: {
    audienceRole: 'all',
    category: 'system',
    channels: ['inbox'],
    priority: 2,
    entityType: null,
  },
};

export function isValidAudienceRole(value) {
  return AUDIENCE_ROLES.includes(value);
}

export function isValidCategory(value) {
  return NOTIFICATION_CATEGORIES.includes(value);
}

export function isValidChannel(value) {
  return NOTIFICATION_CHANNELS.includes(value);
}

function normalizeChannels(channels, fallbackChannels) {
  const source = Array.isArray(channels) && channels.length > 0 ? channels : fallbackChannels;

  const normalized = [...new Set(source.filter((channel) => isValidChannel(channel)))];
  return normalized.length > 0 ? normalized : [...DEFAULT_NOTIFICATION_CHANNELS];
}

function normalizePriority(priority, fallbackPriority) {
  const candidate = Number.isFinite(Number(priority)) ? Number(priority) : Number(fallbackPriority);

  if (!Number.isFinite(candidate)) {
    return DEFAULT_NOTIFICATION_PRIORITY;
  }

  return Math.max(1, Math.min(5, Math.trunc(candidate)));
}

export function resolveNotificationContract(type, overrides = {}) {
  const safeType = String(type || '').trim();
  const fromRegistry = NOTIFICATION_TYPE_REGISTRY[safeType] || null;

  const audienceRole = isValidAudienceRole(overrides.audienceRole)
    ? overrides.audienceRole
    : fromRegistry?.audienceRole || 'all';

  const category = isValidCategory(overrides.category)
    ? overrides.category
    : fromRegistry?.category || 'system';

  const channels = normalizeChannels(
    overrides.channels,
    fromRegistry?.channels || DEFAULT_NOTIFICATION_CHANNELS
  );

  const priority = normalizePriority(
    overrides.priority,
    fromRegistry?.priority || DEFAULT_NOTIFICATION_PRIORITY
  );

  return {
    type: safeType,
    audienceRole,
    category,
    channels,
    priority,
    entityType: overrides.entityType ?? fromRegistry?.entityType ?? null,
  };
}
