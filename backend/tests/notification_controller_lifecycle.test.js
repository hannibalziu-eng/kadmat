import { jest, describe, beforeEach, it, expect } from '@jest/globals';

const trackNotificationLifecycleEventsMock = jest.fn();

jest.unstable_mockModule('../src/config/supabase.js', () => ({
  supabase: {
    from: jest.fn(),
  },
  supabaseAdmin: {
    from: jest.fn(),
  },
}));

jest.unstable_mockModule('../src/services/notificationTelemetryService.js', () => ({
  trackNotificationLifecycleEvents: trackNotificationLifecycleEventsMock,
}));

const { trackLifecycle } = await import('../src/controllers/notificationController.js');

function createRes() {
  const res = {
    status: jest.fn(() => res),
    json: jest.fn(() => res),
  };
  return res;
}

describe('notificationController.trackLifecycle', () => {
  beforeEach(() => {
    trackNotificationLifecycleEventsMock.mockReset();
    trackNotificationLifecycleEventsMock.mockResolvedValue({
      accepted: 1,
      persisted: 1,
      skipped: 0,
    });
  });

  it('returns 400 when lifecycle event payload is invalid', async () => {
    const req = {
      user: { id: 'u-1' },
      requestId: 'req-api-1',
      body: { stage: 'opened', requestId: '', eventType: '' },
    };
    const res = createRes();

    await expect(trackLifecycle(req, res)).rejects.toMatchObject({
      statusCode: 400,
      code: 'VALIDATION_FAILED',
    });

    expect(res.status).not.toHaveBeenCalled();
    expect(trackNotificationLifecycleEventsMock).not.toHaveBeenCalled();
  });

  it('tracks valid lifecycle event and returns aggregate stats', async () => {
    const req = {
      user: { id: 'u-2' },
      requestId: 'req-api-2',
      body: {
        stage: 'opened',
        requestId: 'req-push-8',
        eventType: 'new_offer',
        source: 'inbox_tap',
      },
    };
    const res = createRes();

    await trackLifecycle(req, res);

    expect(trackNotificationLifecycleEventsMock).toHaveBeenCalledWith(
      [req.body],
      {
        fallbackUserId: 'u-2',
        fallbackSource: 'mobile_client',
        persist: true,
      }
    );
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        requestId: 'req-api-2',
        accepted: 1,
        persisted: 1,
        skipped: 0,
      })
    );
  });
});
