import { describe, it, expect } from '@jest/globals';
import request from 'supertest';
import express from 'express';

import {
  attachRequestContext,
  normalizeErrorResponse,
} from '../src/middleware/errorContractMiddleware.js';

describe('Error contract middleware', () => {
  const app = express();
  app.use(express.json());
  app.use(attachRequestContext);
  app.use(normalizeErrorResponse);

  app.get('/legacy-error', (req, res) => {
    res.status(400).json({ error: 'Legacy error payload' });
  });

  app.get('/legacy-message', (req, res) => {
    res.status(401).json({ success: false, message: 'Not authorized' });
  });

  app.get('/structured-error', (req, res) => {
    res.status(409).json({
      success: false,
      error: {
        code: 'JOB_ALREADY_ACCEPTED',
        message: 'Job already accepted',
      },
    });
  });

  it('normalizes legacy {error: string} payload to standard contract', async () => {
    const res = await request(app).get('/legacy-error');

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('INVALID_INPUT');
    expect(res.body.error.message).toBe('Legacy error payload');
    expect(res.body.error.requestId).toBeDefined();
    expect(res.body.path).toBe('/legacy-error');
    expect(res.body.timestamp).toBeDefined();
    expect(res.headers['x-request-id']).toBe(res.body.error.requestId);
  });

  it('normalizes legacy {success:false,message} payload', async () => {
    const res = await request(app).get('/legacy-message');

    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
    expect(res.body.error.message).toBe('Not authorized');
    expect(res.body.error.requestId).toBeDefined();
  });

  it('keeps structured error and enriches with requestId/path', async () => {
    const res = await request(app).get('/structured-error');

    expect(res.status).toBe(409);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('JOB_ALREADY_ACCEPTED');
    expect(res.body.error.message).toBe('Job already accepted');
    expect(res.body.error.requestId).toBeDefined();
    expect(res.body.path).toBe('/structured-error');
  });
});
