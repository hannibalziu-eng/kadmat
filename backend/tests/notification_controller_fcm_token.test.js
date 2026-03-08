import { jest, describe, beforeEach, it, expect } from '@jest/globals';

const fromAdminMock = jest.fn();
const updateMock = jest.fn();
const eqMock = jest.fn();

jest.unstable_mockModule('../src/config/supabase.js', () => ({
  supabase: {
    from: jest.fn(),
  },
  supabaseAdmin: {
    from: fromAdminMock,
  },
}));

jest.unstable_mockModule('../src/services/notificationTelemetryService.js', () => ({
  trackNotificationLifecycleEvents: jest.fn(),
}));

const { updateFCMToken } = await import('../src/controllers/notificationController.js');

function createRes() {
  const res = {
    status: jest.fn(() => res),
    json: jest.fn(() => res),
  };
  return res;
}

describe('notificationController.updateFCMToken', () => {
  beforeEach(() => {
    fromAdminMock.mockReset();
    updateMock.mockReset();
    eqMock.mockReset();

    updateMock.mockReturnThis();
    eqMock.mockResolvedValue({ error: null });
    fromAdminMock.mockReturnValue({
      update: updateMock,
      eq: eqMock,
    });
  });

  it('updates users.fcm_token via supabaseAdmin with trimmed token', async () => {
    const token = 'a'.repeat(200);
    const req = {
      user: { id: 'user-123' },
      body: { fcmToken: `  ${token}  ` },
    };
    const res = createRes();

    await updateFCMToken(req, res);

    expect(fromAdminMock).toHaveBeenCalledWith('users');
    expect(updateMock).toHaveBeenCalledWith({ fcm_token: token });
    expect(eqMock).toHaveBeenCalledWith('id', 'user-123');
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
      })
    );
  });

  it('throws validation error when fcm token is invalid', async () => {
    const req = {
      user: { id: 'user-123' },
      body: { fcmToken: 'short' },
    };
    const res = createRes();

    await expect(updateFCMToken(req, res)).rejects.toMatchObject({
      statusCode: 400,
      code: 'VALIDATION_FAILED',
    });
    expect(fromAdminMock).not.toHaveBeenCalled();
  });

  it('throws database error when update fails', async () => {
    eqMock.mockResolvedValue({
      error: { code: 'DB_FAIL', message: 'db failed' },
    });

    const req = {
      user: { id: 'user-123' },
      body: { fcmToken: 'b'.repeat(200) },
    };
    const res = createRes();

    await expect(updateFCMToken(req, res)).rejects.toMatchObject({
      statusCode: 500,
      code: 'DATABASE_ERROR',
    });
  });
});
