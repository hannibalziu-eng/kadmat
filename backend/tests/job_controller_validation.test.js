import { jest, describe, it, expect, beforeEach } from '@jest/globals';
import request from 'supertest';
import express from 'express';

const jobServiceMock = {
  submitOffer: jest.fn(),
  rate: jest.fn(),
};

jest.unstable_mockModule('../src/config/supabase.js', () => {
  const chain = {
    select: jest.fn().mockReturnThis(),
    insert: jest.fn().mockReturnThis(),
    update: jest.fn().mockReturnThis(),
    delete: jest.fn().mockReturnThis(),
    eq: jest.fn().mockReturnThis(),
    in: jest.fn().mockReturnThis(),
    neq: jest.fn().mockReturnThis(),
    or: jest.fn().mockReturnThis(),
    order: jest.fn().mockReturnThis(),
    range: jest.fn(async () => ({ data: [], error: null, count: 0 })),
    maybeSingle: jest.fn(() => ({ data: null, error: null })),
    single: jest.fn(() => ({ data: null, error: null })),
  };

  return {
    supabase: {
      from: jest.fn(() => chain),
    },
    supabaseAdmin: {
      from: jest.fn(() => chain),
      rpc: jest.fn(async () => ({ data: [], error: null })),
    },
  };
});

jest.unstable_mockModule('../src/services/jobService.js', () => ({
  jobService: jobServiceMock,
}));

jest.unstable_mockModule('../src/services/jobSearchService.js', () => ({
  startJobSearch: jest.fn(),
  onJobAccepted: jest.fn(),
  cancelJobSearch: jest.fn(),
}));

jest.unstable_mockModule('../src/middleware/authMiddleware.js', () => ({
  protect: (req, res, next) => {
    req.user = { id: 'tech-1', user_type: 'technician' };
    return next();
  },
}));

const { default: jobRoutes } = await import('../src/routes/jobRoutes.js');
const { errorHandler } = await import('../src/middleware/errorHandler.js');

const app = express();
app.use(express.json());
app.use('/api/jobs', jobRoutes);
app.use(errorHandler);

describe('job controller validation', () => {
  beforeEach(() => {
    jobServiceMock.submitOffer.mockReset();
    jobServiceMock.rate.mockReset();
  });

  it('rejects /nearby without lat', async () => {
    const res = await request(app)
      .get('/api/jobs/nearby?lng=46.6')
      .set('Authorization', 'Bearer t');

    expect(res.status).toBe(400);
    expect(res.body?.error?.code).toBe('VALIDATION_FAILED');
  });

  it('rejects /my-jobs when limit is above max', async () => {
    const res = await request(app)
      .get('/api/jobs/my-jobs?limit=999')
      .set('Authorization', 'Bearer t');

    expect(res.status).toBe(400);
    expect(res.body?.error?.code).toBe('VALIDATION_FAILED');
  });

  it('rejects submit-offer when price is missing', async () => {
    const res = await request(app)
      .post('/api/jobs/job-1/submit-offer')
      .set('Authorization', 'Bearer t')
      .send({});

    expect(res.status).toBe(400);
    expect(res.body?.error?.code).toBe('VALIDATION_FAILED');
    expect(jobServiceMock.submitOffer).not.toHaveBeenCalled();
  });

  it('rejects rating outside 1..5', async () => {
    const res = await request(app)
      .post('/api/jobs/job-1/rate')
      .set('Authorization', 'Bearer t')
      .send({ rating: 6, review: 'too high' });

    expect(res.status).toBe(400);
    expect(res.body?.error?.code).toBe('VALIDATION_FAILED');
    expect(jobServiceMock.rate).not.toHaveBeenCalled();
  });

  it('maps JOB_ALREADY_ACCEPTED to HTTP 409 with domain error code', async () => {
    const conflictError = new Error('Job already accepted by another technician');
    conflictError.code = 'JOB_ALREADY_ACCEPTED';
    jobServiceMock.submitOffer.mockRejectedValue(conflictError);

    const res = await request(app)
      .post('/api/jobs/job-1/submit-offer')
      .set('Authorization', 'Bearer t')
      .send({ price: 100 });

    expect(res.status).toBe(409);
    expect(res.body?.error?.code).toBe('JOB_ALREADY_ACCEPTED');
  });
});
