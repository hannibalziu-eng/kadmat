import { jest, describe, beforeEach, it, expect } from '@jest/globals';

const mockState = {
  notifications: [
    {
      id: 'notif-1',
      title: 'New offer',
      type: 'new_offer',
      audience_role: 'technician',
      category: 'offer',
      is_read: false,
      created_at: '2026-02-01T10:00:00.000Z',
    },
  ],
  unreadCount: 3,
  services: [
    {
      id: 'service-1',
      name: 'Plumbing',
      is_active: true,
    },
  ],
};

const buildNotificationsListChain = () => ({
  eq: jest.fn().mockReturnThis(),
  in: jest.fn().mockReturnThis(),
  order: jest.fn().mockReturnThis(),
  lt: jest.fn().mockReturnThis(),
  limit: jest.fn(async () => ({
    data: mockState.notifications,
    error: null,
    count: mockState.notifications.length,
  })),
  range: jest.fn(async () => ({
    data: mockState.notifications,
    error: null,
    count: mockState.notifications.length,
  })),
});

const buildUnreadHeadChain = () => {
  const chain = {
    eq: jest.fn(),
    in: jest.fn().mockReturnThis(),
  };

  chain.eq.mockImplementation((field) => {
    if (field === 'is_read') {
      return Promise.resolve({ count: mockState.unreadCount, error: null });
    }
    return chain;
  });

  return chain;
};

const buildUsersChain = () => ({
  select: jest.fn().mockReturnThis(),
  eq: jest.fn().mockReturnThis(),
  maybeSingle: jest.fn(async () => ({
    data: { user_type: 'technician' },
    error: null,
  })),
});

const buildServicesChain = () => {
  let idFilter = null;
  const chain = {
    select: jest.fn().mockReturnThis(),
    eq: jest.fn((field, value) => {
      if (field === 'id') {
        idFilter = value;
      }
      return chain;
    }),
    order: jest.fn(async () => ({
      data: mockState.services,
      error: null,
    })),
    maybeSingle: jest.fn(async () => ({
      data: mockState.services.find((service) => service.id === idFilter) || null,
      error: null,
    })),
  };
  return chain;
};

jest.unstable_mockModule('../src/config/supabase.js', () => ({
  supabase: {
    from: jest.fn((table) => {
      if (table === 'users') {
        return buildUsersChain();
      }

      if (table === 'services') {
        return buildServicesChain();
      }

      return {
        select: jest.fn().mockReturnThis(),
      };
    }),
  },
  supabaseAdmin: {
    from: jest.fn((table) => {
      if (table === 'notifications') {
        return {
          select: jest.fn((_, options) =>
            options?.head ? buildUnreadHeadChain() : buildNotificationsListChain()
          ),
        };
      }

      return {
        select: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        maybeSingle: jest.fn(async () => ({ data: null, error: null })),
      };
    }),
  },
}));

const { getNotifications, getUnreadCount } = await import(
  '../src/controllers/notificationController.js'
);
const { getServices, getServiceById } = await import('../src/controllers/serviceController.js');

const createRes = () => {
  const res = {
    status: jest.fn(() => res),
    json: jest.fn(() => res),
  };
  return res;
};

describe('controller response contract', () => {
  beforeEach(() => {
    mockState.notifications = [
      {
        id: 'notif-1',
        title: 'New offer',
        type: 'new_offer',
        audience_role: 'technician',
        category: 'offer',
        is_read: false,
        created_at: '2026-02-01T10:00:00.000Z',
      },
    ];
    mockState.unreadCount = 3;
    mockState.services = [
      {
        id: 'service-1',
        name: 'Plumbing',
        is_active: true,
      },
    ];
  });

  it('getNotifications returns normalized data and legacy top-level fields', async () => {
    const req = {
      user: { id: 'tech-1', user_type: 'technician' },
      query: {},
    };
    const res = createRes();

    await getNotifications(req, res);

    const payload = res.json.mock.calls[0][0];
    expect(payload.success).toBe(true);
    expect(payload.data.notifications).toHaveLength(1);
    expect(payload.notifications).toHaveLength(1);
    expect(payload.data.page).toBe(1);
    expect(payload.page).toBe(1);
  });

  it('getUnreadCount returns normalized data and legacy top-level field', async () => {
    const req = {
      user: { id: 'tech-1', user_type: 'technician' },
      query: {},
    };
    const res = createRes();

    await getUnreadCount(req, res);

    const payload = res.json.mock.calls[0][0];
    expect(payload.success).toBe(true);
    expect(payload.data.unread_count).toBe(3);
    expect(payload.unread_count).toBe(3);
  });

  it('getServices returns normalized data and legacy top-level fields', async () => {
    const req = {};
    const res = createRes();

    await getServices(req, res);

    const payload = res.json.mock.calls[0][0];
    expect(payload.success).toBe(true);
    expect(payload.data.services).toHaveLength(1);
    expect(payload.services).toHaveLength(1);
    expect(payload.data.count).toBe(1);
    expect(payload.count).toBe(1);
  });

  it('getServiceById returns normalized data and legacy top-level field', async () => {
    const req = { params: { id: 'service-1' } };
    const res = createRes();

    await getServiceById(req, res);

    const payload = res.json.mock.calls[0][0];
    expect(payload.success).toBe(true);
    expect(payload.data.service.id).toBe('service-1');
    expect(payload.service.id).toBe('service-1');
  });
});
