import { jest, describe, beforeEach, it, expect } from '@jest/globals';

const insertMock = jest.fn();
const fromMock = jest.fn(() => ({
  insert: insertMock,
}));
const recordNotificationLifecycleMock = jest.fn();

jest.unstable_mockModule('../src/config/supabase.js', () => ({
  supabaseAdmin: {
    from: fromMock,
  },
}));

jest.unstable_mockModule('../src/metrics/notificationMetrics.js', () => ({
  recordNotificationLifecycle: recordNotificationLifecycleMock,
}));

const { trackNotificationLifecycleEvents } = await import(
  '../src/services/notificationTelemetryService.js'
);

describe('notification telemetry service', () => {
  beforeEach(() => {
    fromMock.mockClear();
    insertMock.mockReset();
    recordNotificationLifecycleMock.mockClear();
    insertMock.mockResolvedValue({ error: null });
  });

  it('accepts and persists valid lifecycle events', async () => {
    const result = await trackNotificationLifecycleEvents(
      [
        {
          stage: 'received',
          eventType: 'new_offer',
          requestId: 'req-123',
          userId: 'b7b04af4-80ac-4e77-bc9d-b8116a0b8cf1',
          dedupeKey: 'dedupe-123',
          source: 'push_foreground',
        },
      ],
      { persist: true }
    );

    expect(result).toEqual({
      accepted: 1,
      persisted: 1,
      skipped: 0,
    });
    expect(fromMock).toHaveBeenCalledWith('notification_lifecycle_events');
    expect(insertMock).toHaveBeenCalledTimes(1);
    expect(recordNotificationLifecycleMock).toHaveBeenCalledWith(
      expect.objectContaining({
        stage: 'received',
        eventType: 'new_offer',
        source: 'push_foreground',
        outcome: 'accepted',
      })
    );
  });

  it('skips invalid payloads and avoids persistence when nothing valid', async () => {
    const result = await trackNotificationLifecycleEvents(
      [{ stage: 'opened', requestId: '', eventType: '' }],
      { persist: true, fallbackUserId: '7ec89f1d-f937-4e5b-abfe-b4ef96275ad9' }
    );

    expect(result).toEqual({
      accepted: 0,
      persisted: 0,
      skipped: 1,
    });
    expect(fromMock).not.toHaveBeenCalled();
    expect(recordNotificationLifecycleMock).not.toHaveBeenCalled();
  });
});

