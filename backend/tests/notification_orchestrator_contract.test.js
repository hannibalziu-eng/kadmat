import { jest, describe, beforeEach, afterEach, it, expect } from '@jest/globals';

const sendPushNotificationMock = jest.fn(async () => ({ success: true, messageId: 'msg-1' }));
const sendBulkPushNotificationsMock = jest.fn(async () => ({ success: true, sent: 2, failed: 0 }));
const recordNotificationAudienceMismatchMock = jest.fn();
const recordNotificationInboxMock = jest.fn();
const recordNotificationPushMock = jest.fn();
const seenNotificationDedupeKeys = new Set();
const notificationsUpsertBatches = [];
const notificationsInsertBatches = [];

jest.unstable_mockModule('../src/config/supabase.js', () => ({
  supabaseAdmin: {
    from: jest.fn((table) => {
      if (table === 'notifications') {
        return {
          upsert: jest.fn((rows) => {
            const safeRows = Array.isArray(rows) ? rows : [];
            notificationsUpsertBatches.push(safeRows);
            return {
              select: jest.fn(async () => {
                const insertedRows = [];
                for (const row of safeRows) {
                  const dedupeKey = row?.dedupe_key;
                  if (!dedupeKey || seenNotificationDedupeKeys.has(dedupeKey)) {
                    continue;
                  }
                  seenNotificationDedupeKeys.add(dedupeKey);
                  insertedRows.push({ id: dedupeKey });
                }
                return { data: insertedRows, error: null };
              }),
            };
          }),
          insert: jest.fn(async (rows) => {
            const safeRows = Array.isArray(rows) ? rows : [];
            notificationsInsertBatches.push(safeRows);
            return { data: safeRows, error: null };
          }),
        };
      }

      if (table !== 'users') {
        throw new Error('supabase should not be called outside users role lookup');
      }

      return {
        select: jest.fn(() => ({
          in: jest.fn(async (_column, ids) => ({
            data: (ids || []).map((id) => ({
              id,
              user_type: String(id || '').startsWith('tech')
                ? 'technician'
                : 'customer',
            })),
            error: null,
          })),
        })),
      };
    }),
  },
}));

jest.unstable_mockModule('../src/services/fcmService.js', () => ({
  sendPushNotification: sendPushNotificationMock,
  sendBulkPushNotifications: sendBulkPushNotificationsMock,
}));

jest.unstable_mockModule('../src/metrics/notificationMetrics.js', () => ({
  recordNotificationAudienceMismatch: recordNotificationAudienceMismatchMock,
  recordNotificationInbox: recordNotificationInboxMock,
  recordNotificationPush: recordNotificationPushMock,
}));

jest.unstable_mockModule('../src/services/notificationTelemetryService.js', () => ({
  trackNotificationLifecycleEvents: jest.fn(async () => ({
    accepted: 1,
    persisted: 1,
    skipped: 0,
  })),
}));

const { notifyUser, notifyUsers } = await import('../src/services/notificationOrchestrator.js');

describe('notification orchestrator contract integration', () => {
  let warnSpy;

  beforeEach(() => {
    sendPushNotificationMock.mockClear();
    sendBulkPushNotificationsMock.mockClear();
    recordNotificationAudienceMismatchMock.mockClear();
    recordNotificationInboxMock.mockClear();
    recordNotificationPushMock.mockClear();
    seenNotificationDedupeKeys.clear();
    notificationsUpsertBatches.length = 0;
    notificationsInsertBatches.length = 0;
    warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});
  });

  afterEach(() => {
    warnSpy?.mockRestore();
    warnSpy = null;
  });

  it('attaches validated event contract to push payload', async () => {
    const result = await notifyUser({
      userId: 'user-1',
      type: 'warning',
      title: 'تنبيه',
      body: 'اختبار',
      channels: ['push'],
      priority: 4,
      dedupeKey: 'dedupe-1',
      data: {
        job_id: 'job-777',
        deep_link: '/jobs/job-777',
      },
    });

    expect(sendPushNotificationMock).toHaveBeenCalledTimes(1);
    const [, pushPayload] = sendPushNotificationMock.mock.calls[0];

    expect(pushPayload.ttlSeconds).toBe(300);
    expect(pushPayload.collapseKey).toBe('order_job-777');
    expect(pushPayload.channelId).toBe('critical_alerts');

    expect(pushPayload.data.event_type).toBe('warning');
    expect(pushPayload.data.order_id).toBe('job-777');
    expect(pushPayload.data.deep_link).toBe('/jobs/job-777');
    expect(pushPayload.data.dedupe_key).toBe('dedupe-1');

    expect(result.eventContract.event_type).toBe('warning');
    expect(result.eventContract.ttl_seconds).toBe(300);
  });

  it('rejects invalid event contract and skips send', async () => {
    await expect(
      notifyUser({
        userId: 'user-1',
        type: 'warning',
        title: 'تنبيه',
        body: 'اختبار',
        channels: ['push'],
        ttlSeconds: 1,
      })
    ).rejects.toMatchObject({
      code: 'NOTIFICATION_EVENT_CONTRACT_INVALID',
    });

    expect(sendPushNotificationMock).not.toHaveBeenCalled();
  });

  it.each([
    ['job_cancelled_by_customer', 'tech-1', 'order_job-901_status'],
    ['job_cancelled_by_technician', 'customer-1', 'order_job-901_status'],
  ])(
    'builds push contract for %s with critical channel and status collapse',
    async (notificationType, userId, expectedCollapseKey) => {
      const result = await notifyUser({
        userId,
        type: notificationType,
        title: 'تم إلغاء الطلب',
        body: 'اختبار',
        channels: ['push'],
        data: {
          job_id: 'job-901',
          deep_link: '/jobs/job-901',
        },
      });

      expect(sendPushNotificationMock).toHaveBeenCalledTimes(1);
      const [, pushPayload] = sendPushNotificationMock.mock.calls[0];

      expect(pushPayload.ttlSeconds).toBe(1200);
      expect(pushPayload.channelId).toBe('critical_alerts');
      expect(pushPayload.collapseKey).toBe(expectedCollapseKey);

      expect(pushPayload.data.event_type).toBe(notificationType);
      expect(pushPayload.data.order_id).toBe('job-901');
      expect(pushPayload.data.deep_link).toBe('/jobs/job-901');

      expect(result.eventContract.event_type).toBe(notificationType);
      expect(result.eventContract.ttl_seconds).toBe(1200);
      expect(result.eventContract.channel_id).toBe('critical_alerts');
      expect(result.eventContract.collapse_key).toBe(expectedCollapseKey);
    }
  );

  it.each([
    ['job_cancelled_by_customer', 'customer-1'],
    ['job_cancelled_by_technician', 'tech-1'],
  ])(
    'rejects audience mismatch for %s when recipient role is wrong',
    async (notificationType, userId) => {
      await expect(
        notifyUser({
          userId,
          type: notificationType,
          title: 'تم إلغاء الطلب',
          body: 'اختبار',
          channels: ['push'],
          data: {
            job_id: 'job-902',
          },
        })
      ).rejects.toMatchObject({
        code: 'NOTIFICATION_AUDIENCE_MISMATCH',
      });

      expect(sendPushNotificationMock).not.toHaveBeenCalled();
    }
  );

  it.each([
    ['job_cancelled_by_customer', 'customer-1', 'technician'],
    ['job_cancelled_by_technician', 'tech-1', 'customer'],
  ])(
    'allows %s when strictRole=false and records mismatch metric',
    async (notificationType, userId, expectedAudienceRole) => {
      const result = await notifyUser({
        userId,
        type: notificationType,
        title: 'تم إلغاء الطلب',
        body: 'اختبار',
        channels: ['push'],
        strictRole: false,
        data: {
          job_id: 'job-903',
        },
      });

      expect(sendPushNotificationMock).toHaveBeenCalledTimes(1);
      expect(result.push.success).toBe(true);
      expect(recordNotificationAudienceMismatchMock).toHaveBeenCalledWith(
        expectedAudienceRole,
        false,
        1,
      );
    }
  );

  it.each([
    ['job_cancelled_by_customer', ['tech-1', 'customer-1']],
    ['job_cancelled_by_technician', ['customer-1', 'tech-1']],
  ])(
    'notifyUsers rejects audience mismatch for %s when strictRole=true',
    async (notificationType, userIds) => {
      await expect(
        notifyUsers({
          userIds,
          type: notificationType,
          title: 'تم إلغاء الطلب',
          body: 'اختبار',
          channels: ['push'],
          data: {
            job_id: 'job-904',
          },
        })
      ).rejects.toMatchObject({
        code: 'NOTIFICATION_AUDIENCE_MISMATCH',
      });

      expect(sendBulkPushNotificationsMock).not.toHaveBeenCalled();
    }
  );

  it.each([
    ['job_cancelled_by_customer', ['tech-1', 'customer-1'], 'technician'],
    ['job_cancelled_by_technician', ['customer-1', 'tech-1'], 'customer'],
  ])(
    'notifyUsers allows %s when strictRole=false and records mismatch metric',
    async (notificationType, userIds, expectedAudienceRole) => {
      const result = await notifyUsers({
        userIds,
        type: notificationType,
        title: 'تم إلغاء الطلب',
        body: 'اختبار',
        channels: ['push'],
        strictRole: false,
        data: {
          job_id: 'job-905',
          deep_link: '/jobs/job-905',
        },
      });

      expect(sendBulkPushNotificationsMock).toHaveBeenCalledTimes(1);
      const [calledUserIds, bulkPayload] = sendBulkPushNotificationsMock.mock.calls[0];
      expect(calledUserIds).toEqual(userIds);
      expect(bulkPayload.ttlSeconds).toBe(1200);
      expect(bulkPayload.channelId).toBe('critical_alerts');
      expect(bulkPayload.collapseKey).toBe('order_job-905_status');
      expect(bulkPayload.data.event_type).toBe(notificationType);
      expect(bulkPayload.data.order_id).toBe('job-905');

      expect(result.recipients).toBe(userIds.length);
      expect(result.push.success).toBe(true);
      expect(recordNotificationAudienceMismatchMock).toHaveBeenCalledWith(
        expectedAudienceRole,
        false,
        1,
      );
    }
  );

  it('notifyUsers inbox-only flow dedupes repeated sends per recipient', async () => {
    const request = {
      userIds: ['customer-1', 'customer-2'],
      type: 'job_cancelled_by_technician',
      title: 'تم إلغاء الطلب',
      body: 'اختبار',
      channels: ['inbox'],
      data: {
        job_id: 'job-906',
      },
    };

    const first = await notifyUsers(request);
    expect(first.inserted).toBe(2);
    expect(first.deduped).toBe(0);
    expect(first.push.reason).toBe('push_channel_disabled');

    const second = await notifyUsers(request);
    expect(second.inserted).toBe(0);
    expect(second.deduped).toBe(2);
    expect(second.push.reason).toBe('push_channel_disabled');

    expect(sendBulkPushNotificationsMock).not.toHaveBeenCalled();
    expect(notificationsInsertBatches).toHaveLength(0);
    expect(notificationsUpsertBatches).toHaveLength(2);

    const firstBatchKeys = notificationsUpsertBatches[0].map((row) => row.dedupe_key).sort();
    expect(firstBatchKeys).toEqual([
      'job_cancelled_by_technician:job-906:customer-1',
      'job_cancelled_by_technician:job-906:customer-2',
    ]);
    expect(recordNotificationInboxMock).toHaveBeenNthCalledWith(
      1,
      'job_cancelled_by_technician',
      expect.objectContaining({ inserted: 2, deduped: 0 }),
    );
    expect(recordNotificationInboxMock).toHaveBeenNthCalledWith(
      2,
      'job_cancelled_by_technician',
      expect.objectContaining({ inserted: 0, deduped: 2 }),
    );
    expect(recordNotificationPushMock).toHaveBeenNthCalledWith(
      1,
      'job_cancelled_by_technician',
      expect.objectContaining({ reason: 'push_channel_disabled' }),
    );
    expect(recordNotificationPushMock).toHaveBeenNthCalledWith(
      2,
      'job_cancelled_by_technician',
      expect.objectContaining({ reason: 'push_channel_disabled' }),
    );
  });
});
