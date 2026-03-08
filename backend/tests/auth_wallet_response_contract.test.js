import { jest, describe, beforeEach, it, expect } from '@jest/globals';

const walletServiceMock = {
  getBalance: jest.fn(),
  getTransactions: jest.fn(),
  requestWithdrawal: jest.fn(),
  getWithdrawals: jest.fn(),
};

jest.unstable_mockModule('../src/config/supabase.js', () => ({
  supabase: {
    auth: {
      signInWithPassword: jest.fn(async () => ({
        data: {
          session: {
            access_token: 'access-1',
            refresh_token: 'refresh-1',
            expires_at: 1234567890,
          },
          user: { id: 'user-1' },
        },
        error: null,
      })),
      refreshSession: jest.fn(async () => ({
        data: {
          session: {
            access_token: 'access-2',
            refresh_token: 'refresh-2',
            expires_at: 1234567999,
          },
        },
        error: null,
      })),
    },
    from: jest.fn(() => ({
      select: jest.fn().mockReturnThis(),
      eq: jest.fn().mockReturnThis(),
      single: jest.fn(async () => ({
        data: {
          id: 'user-1',
          full_name: 'User One',
          user_type: 'technician',
          wallet: { balance: 120, currency: 'SAR' },
        },
        error: null,
      })),
    })),
  },
  supabaseAdmin: {
    auth: {
      admin: {
        createUser: jest.fn(async () => ({
          data: {
            user: {
              id: 'user-new',
              email: 'new@example.com',
              user_metadata: { full_name: 'New User', user_type: 'customer' },
            },
          },
          error: null,
        })),
      },
    },
  },
}));

jest.unstable_mockModule('../src/services/walletService.js', () => ({
  walletService: walletServiceMock,
}));

const { register, login, refreshToken } = await import('../src/controllers/authController.js');
const {
  getWallet,
  getWalletTransactions,
  requestWithdrawal,
  getWithdrawals,
} = await import('../src/controllers/walletController.js');

const createRes = () => {
  const res = {
    status: jest.fn(() => res),
    json: jest.fn(() => res),
  };
  return res;
};

describe('auth/wallet response contract', () => {
  beforeEach(() => {
    walletServiceMock.getBalance.mockReset();
    walletServiceMock.getTransactions.mockReset();
    walletServiceMock.requestWithdrawal.mockReset();
    walletServiceMock.getWithdrawals.mockReset();
  });

  it('register returns data.user and legacy top-level user', async () => {
    const req = {
      body: {
        email: 'new@example.com',
        password: '123456',
        phone: '0500000000',
        full_name: 'New User',
        user_type: 'customer',
      },
    };
    const res = createRes();

    await register(req, res);

    const body = res.json.mock.calls[0][0];
    expect(res.status).toHaveBeenCalledWith(201);
    expect(body.success).toBe(true);
    expect(body.data.user.id).toBe('user-new');
    expect(body.user.id).toBe('user-new');
  });

  it('login returns data tokens and legacy top-level tokens', async () => {
    const req = { body: { email: 'test@example.com', password: '123456' } };
    const res = createRes();

    await login(req, res);

    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(true);
    expect(body.data.token).toBe('access-1');
    expect(body.token).toBe('access-1');
    expect(body.data.refresh_token).toBe('refresh-1');
    expect(body.refresh_token).toBe('refresh-1');
  });

  it('refresh returns data tokens and legacy top-level tokens', async () => {
    const req = { body: { refresh_token: 'refresh-token-1' } };
    const res = createRes();

    await refreshToken(req, res);

    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(true);
    expect(body.data.token).toBe('access-2');
    expect(body.token).toBe('access-2');
    expect(body.data.refresh_token).toBe('refresh-2');
    expect(body.refresh_token).toBe('refresh-2');
  });

  it('wallet endpoints return expected shape with pagination compatibility', async () => {
    walletServiceMock.getBalance.mockResolvedValue({ balance: 300, currency: 'SAR' });
    walletServiceMock.getTransactions.mockResolvedValue({
      transactions: [{ id: 't1', amount: 100 }],
      total: 1,
      page: 1,
      totalPages: 1,
    });
    walletServiceMock.requestWithdrawal.mockResolvedValue({
      id: 'w1',
      amount: 50,
      status: 'pending',
    });
    walletServiceMock.getWithdrawals.mockResolvedValue({
      withdrawals: [{ id: 'wd1', amount: 50 }],
      total: 1,
      page: 1,
      totalPages: 1,
    });

    const userReq = { user: { id: 'user-1' }, query: { page: 1, limit: 20 } };

    const walletRes = createRes();
    await getWallet(userReq, walletRes);
    expect(walletRes.json.mock.calls[0][0].success).toBe(true);
    expect(walletRes.json.mock.calls[0][0].data.balance).toBe(300);

    const txRes = createRes();
    await getWalletTransactions(userReq, txRes);
    expect(txRes.json.mock.calls[0][0].success).toBe(true);
    expect(Array.isArray(txRes.json.mock.calls[0][0].data)).toBe(true);
    expect(txRes.json.mock.calls[0][0].pagination.total).toBe(1);

    const withdrawReq = { user: { id: 'user-1' }, body: { amount: 50 } };
    const withdrawRes = createRes();
    await requestWithdrawal(withdrawReq, withdrawRes);
    expect(withdrawRes.status).toHaveBeenCalledWith(201);
    expect(withdrawRes.json.mock.calls[0][0].success).toBe(true);
    expect(withdrawRes.json.mock.calls[0][0].data.id).toBe('w1');

    const wdRes = createRes();
    await getWithdrawals(userReq, wdRes);
    expect(wdRes.json.mock.calls[0][0].success).toBe(true);
    expect(Array.isArray(wdRes.json.mock.calls[0][0].data)).toBe(true);
    expect(wdRes.json.mock.calls[0][0].pagination.total).toBe(1);
  });
});
