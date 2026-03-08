import { jest, describe, it, expect, beforeEach } from '@jest/globals';

const beginMock = jest.fn();
const completeMock = jest.fn();

jest.unstable_mockModule('../src/services/idempotencyService.js', () => ({
  idempotencyService: {
    begin: beginMock,
    complete: completeMock,
  },
}));

jest.unstable_mockModule('../src/config/featureFlags.js', () => ({
  featureFlags: {
    idempotencyTtlHours: 48,
    idempotencyStrict: true,
  },
}));

jest.unstable_mockModule('../src/metrics/jobFlowMetrics.js', () => ({
  recordIdempotencyEvent: jest.fn(),
}));

const { requireIdempotencyKey } = await import(
  '../src/middleware/idempotencyMiddleware.js'
);

function buildReq({ userId = 'user-1', baseUrl = '/api/jobs', path = '/job-1/accept-offer', body = {}, headers = {} } = {}) {
  const normalizedHeaders = Object.fromEntries(
    Object.entries(headers).map(([key, value]) => [key.toLowerCase(), value]),
  );

  return {
    user: { id: userId },
    baseUrl,
    path,
    body,
    get(name) {
      return normalizedHeaders[String(name).toLowerCase()];
    },
  };
}

function buildRes() {
  return {
    statusCode: 200,
    payload: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    setHeader: jest.fn(),
    json(body) {
      this.payload = body;
      return this;
    },
  };
}

describe('idempotency middleware', () => {
  beforeEach(() => {
    beginMock.mockReset();
    completeMock.mockReset();
    completeMock.mockResolvedValue(undefined);
  });

  it('rejects request when idempotency header is missing', async () => {
    const middleware = requireIdempotencyKey({ ttlHours: 48 });
    const req = buildReq();
    const res = buildRes();
    const next = jest.fn();

    await middleware(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.statusCode).toBe(400);
    expect(res.payload?.error?.code).toBe('IDEMPOTENCY_KEY_REQUIRED');
  });

  it('replays stored response for completed duplicate request', async () => {
    beginMock.mockResolvedValueOnce({
      kind: 'existing',
      record: {
        status: 'completed',
        request_hash: null,
        response_status: 200,
        response_body: { success: true, data: { id: 'job-1' } },
      },
    });

    const middleware = requireIdempotencyKey({ ttlHours: 48 });
    const req = buildReq({
      headers: { 'x-idempotency-key': 'same-key' },
    });
    const res = buildRes();
    const next = jest.fn();

    await middleware(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.statusCode).toBe(200);
    expect(res.payload).toEqual({ success: true, data: { id: 'job-1' } });
    expect(res.setHeader).toHaveBeenCalledWith('X-Idempotency-Replayed', 'true');
  });

  it('rejects duplicate key with different payload hash', async () => {
    beginMock.mockResolvedValueOnce({
      kind: 'existing',
      record: {
        status: 'processing',
        request_hash: 'different-hash',
      },
    });

    const middleware = requireIdempotencyKey({ ttlHours: 48 });
    const req = buildReq({
      headers: { 'x-idempotency-key': 'same-key' },
      body: { offerId: 'offer-1' },
    });
    const res = buildRes();
    const next = jest.fn();

    await middleware(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.statusCode).toBe(409);
    expect(res.payload?.error?.code).toBe('IDEMPOTENCY_PAYLOAD_MISMATCH');
  });

  it('persists response for new key after controller writes json', async () => {
    beginMock.mockResolvedValueOnce({
      kind: 'new',
      record: {
        id: 'idem-1',
      },
    });

    const middleware = requireIdempotencyKey({ ttlHours: 48 });
    const req = buildReq({
      headers: { 'x-idempotency-key': 'fresh-key' },
      body: { offerId: 'offer-1' },
    });
    const res = buildRes();
    const next = jest.fn();

    await middleware(req, res, next);
    expect(next).toHaveBeenCalledTimes(1);

    res.status(201).json({ success: true, data: { ok: true } });
    await Promise.resolve();

    expect(completeMock).toHaveBeenCalledWith({
      recordId: 'idem-1',
      statusCode: 201,
      responseBody: { success: true, data: { ok: true } },
    });
  });
});
