import { supabaseAdmin } from '../config/supabase.js';
import crypto from 'crypto';
import { sendBulkPushNotifications, sendPushNotification } from './fcmService.js';
import {
  isValidAudienceRole,
  resolveNotificationContract,
} from '../constants/notificationContract.js';
import { buildAndValidateNotificationEvent } from '../constants/notificationEventContract.js';
import {
  resolveNotificationEventPolicy,
  resolveNotificationDedupeKey,
} from '../constants/notificationEventPolicy.js';
import {
  recordNotificationAudienceMismatch,
  recordNotificationInbox,
  recordNotificationPush,
} from '../metrics/notificationMetrics.js';
import { trackNotificationLifecycleEvents } from './notificationTelemetryService.js';
import logger from '../utils/logger.js';

function toIsoNow() {
  return new Date().toISOString();
}

function toObject(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }
  return value;
}

function resolveEntityId(data, explicitEntityId) {
  if (typeof explicitEntityId === 'string' && explicitEntityId.trim()) {
    return explicitEntityId.trim();
  }

  const payload = toObject(data);
  const candidate = payload.entity_id ?? payload.job_id ?? payload.jobId ?? null;
  if (typeof candidate === 'string' && candidate.trim()) {
    return candidate.trim();
  }

  return null;
}

function resolveRequestId(data, explicitRequestId) {
  if (typeof explicitRequestId === 'string' && explicitRequestId.trim()) {
    return explicitRequestId.trim();
  }

  const payload = toObject(data);
  const candidate = payload.request_id ?? payload.requestId ?? null;
  if (typeof candidate === 'string' && candidate.trim()) {
    return candidate.trim();
  }

  return crypto.randomUUID();
}

function buildPushData({ type, data, entityType, entityId, category, eventContract, requestId }) {
  const payload = toObject(data);

  return {
    ...payload,
    type,
    event_type: eventContract.event_type,
    category,
    priority: String(eventContract.priority),
    ttl_seconds: String(eventContract.ttl_seconds),
    ...(entityType ? { entity_type: entityType } : {}),
    ...(entityId ? { entity_id: entityId } : {}),
    ...(requestId ? { request_id: requestId } : {}),
    ...(eventContract.order_id ? { order_id: eventContract.order_id } : {}),
    ...(eventContract.deep_link ? { deep_link: eventContract.deep_link } : {}),
    ...(eventContract.dedupe_key ? { dedupe_key: eventContract.dedupe_key } : {}),
    ...(eventContract.collapse_key ? { collapse_key: eventContract.collapse_key } : {}),
    ...(eventContract.channel_id ? { channel_id: eventContract.channel_id } : {}),
  };
}

async function fetchUserRoles(userIds) {
  const uniqueUserIds = [...new Set((userIds || []).filter(Boolean))];
  if (uniqueUserIds.length === 0) {
    return new Map();
  }

  const { data, error } = await supabaseAdmin
    .from('users')
    .select('id, user_type')
    .in('id', uniqueUserIds);

  if (error) {
    const err = new Error(`Failed to fetch recipient roles: ${error.message}`);
    err.code = 'NOTIFICATION_ROLE_LOOKUP_FAILED';
    throw err;
  }

  const roleMap = new Map();
  for (const item of data || []) {
    roleMap.set(item.id, item.user_type || null);
  }

  return roleMap;
}

async function enforceAudienceRole({ userIds, audienceRole, strict }) {
  if (!isValidAudienceRole(audienceRole) || audienceRole === 'all' || audienceRole === 'admin') {
    return;
  }

  const roleMap = await fetchUserRoles(userIds);
  const mismatches = [];

  for (const userId of userIds) {
    const userRole = roleMap.get(userId);
    if (!userRole || userRole !== audienceRole) {
      mismatches.push({ userId, userRole: userRole || 'unknown' });
    }
  }

  if (mismatches.length === 0) {
    return;
  }

  logger.warn('⚠️ notification.audience_mismatch', {
    audienceRole,
    mismatchesCount: mismatches.length,
    mismatches,
  });
  recordNotificationAudienceMismatch(audienceRole, strict, mismatches.length);

  if (strict) {
    const err = new Error('Notification audience mismatch');
    err.code = 'NOTIFICATION_AUDIENCE_MISMATCH';
    err.details = { audienceRole, mismatches };
    throw err;
  }
}

function toNotificationRow({
  userId,
  type,
  title,
  body,
  data,
  isRead,
  audienceRole,
  category,
  channels,
  entityType,
  entityId,
  dedupeKey,
  priority,
  requestId,
}) {
  const payload = toObject(data);
  const normalizedData = {
    ...payload,
    type,
    ...(requestId ? { request_id: requestId } : {}),
    ...(dedupeKey ? { dedupe_key: dedupeKey } : {}),
    ...(entityType ? { entity_type: entityType } : {}),
    ...(entityId ? { entity_id: entityId } : {}),
  };

  return {
    user_id: userId,
    type,
    title,
    body,
    data: normalizedData,
    is_read: Boolean(isRead),
    audience_role: audienceRole,
    category,
    channels,
    entity_type: entityType,
    entity_id: entityId,
    dedupe_key: dedupeKey,
    priority,
    created_at: toIsoNow(),
  };
}

function normalizeDedupeKey(dedupeKey) {
  if (typeof dedupeKey !== 'string') {
    return null;
  }

  const value = dedupeKey.trim();
  return value.length > 0 ? value : null;
}

async function insertNotificationRows(rows) {
  if (!rows || rows.length === 0) {
    return { inserted: 0, deduped: 0 };
  }

  const rowsWithDedupe = rows.filter((row) => row.dedupe_key);
  const rowsWithoutDedupe = rows.filter((row) => !row.dedupe_key);

  let inserted = 0;
  let deduped = 0;

  if (rowsWithDedupe.length > 0) {
    const { data, error } = await supabaseAdmin
      .from('notifications')
      .upsert(rowsWithDedupe, {
        onConflict: 'dedupe_key',
        ignoreDuplicates: true,
      })
      .select('id');

    if (error) {
      const err = new Error(`Failed to upsert notifications: ${error.message}`);
      err.code = 'NOTIFICATION_INSERT_FAILED';
      throw err;
    }

    inserted += data?.length || 0;
    deduped += Math.max(0, rowsWithDedupe.length - (data?.length || 0));
  }

  if (rowsWithoutDedupe.length > 0) {
    const { error } = await supabaseAdmin.from('notifications').insert(rowsWithoutDedupe);

    if (error) {
      const err = new Error(`Failed to insert notifications: ${error.message}`);
      err.code = 'NOTIFICATION_INSERT_FAILED';
      throw err;
    }

    inserted += rowsWithoutDedupe.length;
  }

  return { inserted, deduped };
}

function ensureRequiredFields({ userId, type, title, body }) {
  if (!userId) {
    const err = new Error('Notification userId is required');
    err.code = 'NOTIFICATION_VALIDATION_FAILED';
    throw err;
  }

  if (!type || typeof type !== 'string') {
    const err = new Error('Notification type is required');
    err.code = 'NOTIFICATION_VALIDATION_FAILED';
    throw err;
  }

  if (!title || typeof title !== 'string') {
    const err = new Error('Notification title is required');
    err.code = 'NOTIFICATION_VALIDATION_FAILED';
    throw err;
  }

  if (!body || typeof body !== 'string') {
    const err = new Error('Notification body is required');
    err.code = 'NOTIFICATION_VALIDATION_FAILED';
    throw err;
  }
}

export async function notifyUser({
  userId,
  type,
  title,
  body,
  data = {},
  isRead = false,
  audienceRole,
  category,
  channels,
  entityType,
  entityId,
  dedupeKey,
  priority,
  strictRole = true,
  pushTitle,
  pushBody,
  pushData,
  ttlSeconds,
  collapseKey,
  deepLink,
  pushChannelId,
  requestId,
}) {
  ensureRequiredFields({ userId, type, title, body });

  const contract = resolveNotificationContract(type, {
    audienceRole,
    category,
    channels,
    priority,
    entityType,
  });

  const resolvedEntityId = resolveEntityId(data, entityId);
  const resolvedRequestId = resolveRequestId(data, requestId);
  const eventPolicy = resolveNotificationEventPolicy(contract.type, {
    ttlSeconds,
    pushChannelId,
  });
  const resolvedDedupeKey = resolveNotificationDedupeKey({
    explicitDedupeKey: normalizeDedupeKey(dedupeKey),
    eventType: contract.type,
    orderId: resolvedEntityId,
    userId,
    autoDedupe: eventPolicy.autoDedupe,
  });
  const eventContract = buildAndValidateNotificationEvent({
    eventType: contract.type,
    data: pushData || data,
    entityId: resolvedEntityId,
    dedupeKey: resolvedDedupeKey,
    priority: contract.priority,
    ttlSeconds: ttlSeconds ?? eventPolicy.ttlSeconds,
    defaultTtlSeconds: eventPolicy.ttlSeconds,
    collapseKey,
    collapseScope: eventPolicy.collapseScope,
    deepLink,
    channelId: pushChannelId ?? eventPolicy.pushChannelId,
    defaultChannelId: eventPolicy.pushChannelId,
  });

  await enforceAudienceRole({
    userIds: [userId],
    audienceRole: contract.audienceRole,
    strict: strictRole,
  });

  let insertResult = { inserted: 0, deduped: 0 };

  if (contract.channels.includes('inbox')) {
    const row = toNotificationRow({
      userId,
      type: contract.type,
      title,
      body,
      data,
      isRead,
      audienceRole: contract.audienceRole,
      category: contract.category,
      channels: contract.channels,
      entityType: contract.entityType,
      entityId: resolvedEntityId,
      dedupeKey: resolvedDedupeKey,
      priority: contract.priority,
      requestId: resolvedRequestId,
    });

    insertResult = await insertNotificationRows([row]);
    recordNotificationInbox(contract.type, insertResult);
  } else {
    recordNotificationInbox(contract.type, { skipped: true });
  }

  let pushResult = { success: false, reason: 'push_channel_disabled' };
  if (contract.channels.includes('push')) {
    pushResult = await sendPushNotification(userId, {
      title: pushTitle || title,
      body: pushBody || body,
      priority: contract.priority,
      ttlSeconds: eventContract.ttl_seconds,
      collapseKey: eventContract.collapse_key,
      channelId: eventContract.channel_id,
      data: buildPushData({
        type: contract.type,
        data: pushData || data,
        category: contract.category,
        entityType: contract.entityType,
        entityId: resolvedEntityId,
        eventContract,
        requestId: resolvedRequestId,
      }),
    });
  }
  recordNotificationPush(contract.type, pushResult);

  if (insertResult.inserted > 0 || pushResult.success === true) {
    await trackNotificationLifecycleEvents(
      [
        {
          stage: 'sent',
          eventType: contract.type,
          requestId: resolvedRequestId,
          dedupeKey: resolvedDedupeKey,
          entityId: resolvedEntityId,
          userId,
          source: 'backend',
          metadata: {
            channels: contract.channels,
            inserted: insertResult.inserted,
            deduped: insertResult.deduped,
            pushSent: pushResult.success === true,
          },
        },
      ],
      { fallbackUserId: userId, fallbackSource: 'backend' }
    );
  }

  return {
    contract,
    policy: eventPolicy,
    eventContract,
    requestId: resolvedRequestId,
    inserted: insertResult.inserted,
    deduped: insertResult.deduped,
    push: pushResult,
  };
}

export async function notifyUsers({
  userIds,
  type,
  title,
  body,
  data = {},
  isRead = false,
  audienceRole,
  category,
  channels,
  entityType,
  entityId,
  dedupeKey,
  priority,
  strictRole = true,
  pushTitle,
  pushBody,
  pushData,
  ttlSeconds,
  collapseKey,
  deepLink,
  pushChannelId,
  requestId,
}) {
  const uniqueUserIds = [...new Set((userIds || []).filter(Boolean))];
  if (uniqueUserIds.length === 0) {
    return {
      contract: resolveNotificationContract(type, {
        audienceRole,
        category,
        channels,
        priority,
        entityType,
      }),
      inserted: 0,
      deduped: 0,
      push: { success: false, reason: 'no_recipients' },
    };
  }

  ensureRequiredFields({ userId: uniqueUserIds[0], type, title, body });

  const contract = resolveNotificationContract(type, {
    audienceRole,
    category,
    channels,
    priority,
    entityType,
  });

  const resolvedEntityId = resolveEntityId(data, entityId);
  const resolvedRequestId = resolveRequestId(data, requestId);
  const eventPolicy = resolveNotificationEventPolicy(contract.type, {
    ttlSeconds,
    pushChannelId,
  });
  const dedupeBase = resolveNotificationDedupeKey({
    explicitDedupeKey: normalizeDedupeKey(dedupeKey),
    eventType: contract.type,
    orderId: resolvedEntityId,
    autoDedupe: eventPolicy.autoDedupe,
  });
  const eventContract = buildAndValidateNotificationEvent({
    eventType: contract.type,
    data: pushData || data,
    entityId: resolvedEntityId,
    dedupeKey: dedupeBase,
    priority: contract.priority,
    ttlSeconds: ttlSeconds ?? eventPolicy.ttlSeconds,
    defaultTtlSeconds: eventPolicy.ttlSeconds,
    collapseKey,
    collapseScope: eventPolicy.collapseScope,
    deepLink,
    channelId: pushChannelId ?? eventPolicy.pushChannelId,
    defaultChannelId: eventPolicy.pushChannelId,
  });

  await enforceAudienceRole({
    userIds: uniqueUserIds,
    audienceRole: contract.audienceRole,
    strict: strictRole,
  });

  let insertResult = { inserted: 0, deduped: 0 };

  if (contract.channels.includes('inbox')) {
    const rows = uniqueUserIds.map((recipientId) =>
      toNotificationRow({
        userId: recipientId,
        type: contract.type,
        title,
        body,
        data,
        isRead,
        audienceRole: contract.audienceRole,
        category: contract.category,
        channels: contract.channels,
        entityType: contract.entityType,
        entityId: resolvedEntityId,
        dedupeKey: dedupeBase ? `${dedupeBase}:${recipientId}` : null,
        priority: contract.priority,
        requestId: resolvedRequestId,
      })
    );

    insertResult = await insertNotificationRows(rows);
    recordNotificationInbox(contract.type, insertResult);
  } else {
    recordNotificationInbox(contract.type, { skipped: true });
  }

  let pushResult = { success: false, reason: 'push_channel_disabled' };
  if (contract.channels.includes('push')) {
    pushResult = await sendBulkPushNotifications(uniqueUserIds, {
      title: pushTitle || title,
      body: pushBody || body,
      priority: contract.priority,
      ttlSeconds: eventContract.ttl_seconds,
      collapseKey: eventContract.collapse_key,
      channelId: eventContract.channel_id,
      data: buildPushData({
        type: contract.type,
        data: pushData || data,
        category: contract.category,
        entityType: contract.entityType,
        entityId: resolvedEntityId,
        eventContract,
        requestId: resolvedRequestId,
      }),
    });
  }
  recordNotificationPush(contract.type, pushResult);

  if (insertResult.inserted > 0 || pushResult.success === true) {
    const events = uniqueUserIds.map((recipientId) => ({
      stage: 'sent',
      eventType: contract.type,
      requestId: resolvedRequestId,
      dedupeKey: dedupeBase ? `${dedupeBase}:${recipientId}` : null,
      entityId: resolvedEntityId,
      userId: recipientId,
      source: 'backend',
      metadata: {
        channels: contract.channels,
        recipients: uniqueUserIds.length,
        inserted: insertResult.inserted,
        deduped: insertResult.deduped,
        pushSent: pushResult.success === true,
      },
    }));

    await trackNotificationLifecycleEvents(events, {
      fallbackSource: 'backend',
    });
  }

  return {
    contract,
    policy: eventPolicy,
    eventContract,
    requestId: resolvedRequestId,
    recipients: uniqueUserIds.length,
    inserted: insertResult.inserted,
    deduped: insertResult.deduped,
    push: pushResult,
  };
}
