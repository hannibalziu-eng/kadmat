import { beforeEach, describe, expect, it, jest } from '@jest/globals';

let jobs;
let messages;
let nextMessageId;

const users = {
  'customer-1': {
    id: 'customer-1',
    full_name: 'عميل الاختبار',
    profile_image_url: 'customer.png',
    phone: '1111111111',
  },
  'tech-1': {
    id: 'tech-1',
    full_name: 'فني الاختبار',
    profile_image_url: 'tech.png',
    phone: '2222222222',
  },
};

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function buildResponseRecorder() {
  const res = {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };

  return res;
}

function enrichMessage(row) {
  return {
    ...clone(row),
    sender: clone(users[row.sender_id]),
  };
}

function applyFilters(rows, filters) {
  return rows.filter((row) => filters.every((filter) => filter(row)));
}

function buildQuery(table) {
  const state = {
    filters: [],
    sort: null,
    insertPayload: null,
    updatePayload: null,
  };

  const query = {
    select: jest.fn(() => query),
    eq: jest.fn((column, value) => {
      state.filters.push((row) => row[column] === value);
      return query;
    }),
    in: jest.fn((column, values) => {
      state.filters.push((row) => values.includes(row[column]));
      return query;
    }),
    or: jest.fn((expression) => {
      const userIds = expression
        .split(',')
        .map((part) => part.split('.eq.')[1])
        .filter(Boolean);
      state.filters.push(
        (row) =>
          userIds.includes(row.customer_id) || userIds.includes(row.technician_id),
      );
      return query;
    }),
    order: jest.fn((column, { ascending }) => {
      state.sort = { column, ascending };
      return query;
    }),
    insert: jest.fn((payload) => {
      state.insertPayload = payload;
      return query;
    }),
    update: jest.fn((payload) => {
      state.updatePayload = payload;
      return query;
    }),
    maybeSingle: jest.fn(async () => {
      const rows = resolveRows(table, state);
      return { data: rows[0] ?? null, error: null };
    }),
    single: jest.fn(async () => {
      const rows = resolveRows(table, state, { single: true });
      return { data: rows[0] ?? null, error: null };
    }),
    then(onFulfilled, onRejected) {
      return Promise.resolve({
        data: resolveRows(table, state),
        error: null,
      }).then(onFulfilled, onRejected);
    },
  };

  return query;
}

function resolveRows(table, state, options = {}) {
  if (table === 'messages' && state.insertPayload) {
    const created = {
      id: `msg-${nextMessageId++}`,
      is_read: false,
      created_at: new Date().toISOString(),
      read_at: null,
      ...state.insertPayload,
    };
    messages.push(created);
    return [enrichMessage(created)];
  }

  const source = table === 'jobs' ? jobs : messages;
  const filtered = applyFilters(source, state.filters);

  if (table === 'messages' && state.updatePayload) {
    const updated = filtered.map((row) => {
      Object.assign(row, state.updatePayload);
      return enrichMessage(row);
    });
    return updated;
  }

  const mapped = filtered.map((row) =>
    table === 'messages' ? enrichMessage(row) : clone(row),
  );

  if (state.sort) {
    mapped.sort((a, b) => {
      const left = a[state.sort.column];
      const right = b[state.sort.column];
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return state.sort.ascending
          ? String(left).localeCompare(String(right))
          : String(right).localeCompare(String(left));
    });
  }

  if (options.single) {
    return mapped.slice(0, 1);
  }

  return mapped;
}

const supabaseMock = {
  from: jest.fn((table) => buildQuery(table)),
};

const fcmServiceMock = {
  sendPushNotification: jest.fn(async () => undefined),
};

jest.unstable_mockModule('../src/config/supabase.js', () => ({
  supabase: supabaseMock,
  supabaseAdmin: supabaseMock,
}));

jest.unstable_mockModule('../src/services/fcmService.js', () => fcmServiceMock);

const {
  getMessages,
  sendMessage,
  getConversations,
} = await import('../src/controllers/messageController.js');

describe('message controller communication policy', () => {
  beforeEach(() => {
    nextMessageId = 1;
    jobs = [
      {
        id: 'job-searching',
        status: 'searching',
        accepted_bid_id: null,
        customer_id: 'customer-1',
        technician_id: 'tech-1',
        created_at: '2026-03-07T00:00:00.000Z',
        customer: clone(users['customer-1']),
        technician: clone(users['tech-1']),
        service: { id: 'service-1', name: 'plumbing_repair', name_ar: 'إصلاح سباكة' },
      },
      {
        id: 'job-accepted',
        status: 'on_the_way',
        accepted_bid_id: 'offer-1',
        customer_id: 'customer-1',
        technician_id: 'tech-1',
        created_at: '2026-03-07T01:00:00.000Z',
        customer: clone(users['customer-1']),
        technician: clone(users['tech-1']),
        service: { id: 'service-1', name: 'plumbing_repair', name_ar: 'إصلاح سباكة' },
      },
      {
        id: 'job-cancelled',
        status: 'cancelled',
        accepted_bid_id: 'offer-2',
        customer_id: 'customer-1',
        technician_id: 'tech-1',
        created_at: '2026-03-07T02:00:00.000Z',
        customer: clone(users['customer-1']),
        technician: clone(users['tech-1']),
        service: { id: 'service-1', name: 'plumbing_repair', name_ar: 'إصلاح سباكة' },
      },
      {
        id: 'job-legacy',
        status: 'completed',
        accepted_bid_id: null,
        customer_id: 'customer-1',
        technician_id: 'tech-1',
        created_at: '2026-03-07T03:00:00.000Z',
        customer: clone(users['customer-1']),
        technician: clone(users['tech-1']),
        service: { id: 'service-1', name: 'plumbing_repair', name_ar: 'إصلاح سباكة' },
      },
    ];

    messages = [
      {
        id: 'seed-1',
        job_id: 'job-accepted',
        sender_id: 'tech-1',
        receiver_id: 'customer-1',
        content: 'أنا في الطريق',
        is_read: false,
        created_at: '2026-03-07T01:10:00.000Z',
        read_at: null,
      },
      {
        id: 'seed-2',
        job_id: 'job-cancelled',
        sender_id: 'tech-1',
        receiver_id: 'customer-1',
        content: 'هذه الرسالة يجب أن تختفي',
        is_read: false,
        created_at: '2026-03-07T02:10:00.000Z',
        read_at: null,
      },
      {
        id: 'seed-3',
        job_id: 'job-legacy',
        sender_id: 'tech-1',
        receiver_id: 'customer-1',
        content: 'تم الإنجاز',
        is_read: true,
        created_at: '2026-03-07T03:10:00.000Z',
        read_at: '2026-03-07T03:15:00.000Z',
      },
    ];

    supabaseMock.from.mockClear();
    fcmServiceMock.sendPushNotification.mockClear();
  });

  it('blocks reading messages before the offer is accepted', async () => {
    const res = buildResponseRecorder();

    await getMessages(
      {
        params: { jobId: 'job-searching' },
        user: { id: 'customer-1' },
      },
      res,
    );

    expect(res.statusCode).toBe(403);
    expect(res.body.error.code).toBe('COMMUNICATION_NOT_AVAILABLE');
  });

  it('blocks sending messages before the offer is accepted', async () => {
    const res = buildResponseRecorder();

    await sendMessage(
      {
        params: { jobId: 'job-searching' },
        user: { id: 'customer-1' },
        body: { content: 'مرحبا' },
      },
      res,
    );

    expect(res.statusCode).toBe(403);
    expect(res.body.error.code).toBe('COMMUNICATION_NOT_AVAILABLE');
    expect(messages).toHaveLength(3);
  });

  it('allows sending a message after offer acceptance', async () => {
    const res = buildResponseRecorder();

    await sendMessage(
      {
        params: { jobId: 'job-accepted' },
        user: { id: 'customer-1' },
        body: { content: 'ممتاز، بانتظارك' },
      },
      res,
    );

    expect(res.statusCode).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.job_id).toBe('job-accepted');
    expect(messages.at(-1)?.content).toBe('ممتاز، بانتظارك');
    expect(fcmServiceMock.sendPushNotification).toHaveBeenCalledTimes(1);
  });

  it('shows only eligible conversations and keeps unread counts scoped to them', async () => {
    const res = buildResponseRecorder();

    await getConversations(
      {
        user: { id: 'customer-1' },
      },
      res,
    );

    expect(res.statusCode).toBe(200);
    expect(res.body.data).toHaveLength(2);
    expect(res.body.data.map((conversation) => conversation.job_id)).toEqual([
      'job-legacy',
      'job-accepted',
    ]);
    expect(res.body.data.find((conversation) => conversation.job_id === 'job-accepted'))
      .toMatchObject({
        unread_count: 1,
        last_message: 'أنا في الطريق',
        service_name: 'إصلاح سباكة',
      });
    expect(
      res.body.data.find((conversation) => conversation.job_id === 'job-cancelled'),
    ).toBeUndefined();
  });

  it('allows legacy advanced jobs without accepted_bid_id to keep communication open', async () => {
    const res = buildResponseRecorder();

    await getMessages(
      {
        params: { jobId: 'job-legacy' },
        user: { id: 'customer-1' },
      },
      res,
    );

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].job_id).toBe('job-legacy');
  });
});
