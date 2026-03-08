import { jest, describe, it, expect, beforeEach } from '@jest/globals';

const getUserMock = jest.fn();

jest.unstable_mockModule('../src/config/supabase.js', () => ({
  supabase: {
    auth: {
      getUser: getUserMock,
    },
  },
}));

const { protect } = await import('../src/middleware/authMiddleware.js');

function createRes() {
  const res = {
    status: jest.fn(() => res),
    json: jest.fn(() => res),
  };
  return res;
}

describe('authMiddleware.protect', () => {
  beforeEach(() => {
    getUserMock.mockReset();
  });

  it('retries once when Supabase auth lookup fails transiently', async () => {
    getUserMock
      .mockResolvedValueOnce({
        data: { user: null },
        error: {
          message: 'fetch failed',
          cause: { code: 'ECONNRESET' },
        },
      })
      .mockResolvedValueOnce({
        data: { user: { id: 'user-1', email: 'user@example.com' } },
        error: null,
      });

    const req = {
      headers: {
        authorization: 'Bearer token-1',
      },
    };
    const res = createRes();
    const next = jest.fn();

    await protect(req, res, next);

    expect(getUserMock).toHaveBeenCalledTimes(2);
    expect(next).toHaveBeenCalledTimes(1);
    expect(req.user).toMatchObject({ id: 'user-1' });
    expect(res.status).not.toHaveBeenCalled();
  });

  it('returns 401 when auth lookup fails non-transiently', async () => {
    getUserMock.mockResolvedValue({
      data: { user: null },
      error: { message: 'token invalid' },
    });

    const req = {
      headers: {
        authorization: 'Bearer token-2',
      },
    };
    const res = createRes();
    const next = jest.fn();

    await protect(req, res, next);

    expect(getUserMock).toHaveBeenCalledTimes(1);
    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        message: 'Not authorized, token failed',
      })
    );
  });
});
