/**
 * Jobs API Tests (Mock-based)
 * Uses mocked Supabase to test API logic without real database
 */

import { jest, describe, it, expect, beforeAll, afterAll } from '@jest/globals';
import request from 'supertest';
import express from 'express';

// Mock Supabase BEFORE importing routes
jest.unstable_mockModule('../src/config/supabase.js', () => ({
    supabase: {
        auth: {
            getUser: jest.fn(() => ({
                data: { user: { id: 'mock-customer-id-001' } },
                error: null
            }))
        },
        from: jest.fn(() => ({
            select: jest.fn().mockReturnThis(),
            insert: jest.fn().mockReturnThis(),
            update: jest.fn().mockReturnThis(),
            delete: jest.fn().mockReturnThis(),
            eq: jest.fn().mockReturnThis(),
            in: jest.fn().mockReturnThis(),
            single: jest.fn(() => ({
                data: { id: 'mock-job-id', status: 'pending', customer_id: 'mock-customer-id-001' },
                error: null
            })),
            maybeSingle: jest.fn(() => ({
                data: { id: 'mock-job-id', status: 'pending', customer_id: 'mock-customer-id-001' },
                error: null
            }))
        }))
    },
    supabaseAdmin: {
        from: jest.fn(() => ({
            select: jest.fn().mockReturnThis(),
            insert: jest.fn().mockReturnThis(),
            update: jest.fn().mockReturnThis(),
            delete: jest.fn().mockReturnThis(),
            eq: jest.fn().mockReturnThis(),
            in: jest.fn().mockReturnThis(),
            single: jest.fn(() => ({
                data: { id: 'mock-job-id', status: 'pending', customer_id: 'mock-customer-id-001' },
                error: null
            })),
            maybeSingle: jest.fn(() => ({
                data: { id: 'mock-job-id', status: 'pending', customer_id: 'mock-customer-id-001' },
                error: null
            }))
        }))
    }
}));

// Mock auth middleware
jest.unstable_mockModule('../src/middleware/authMiddleware.js', () => ({
    default: (req, res, next) => {
        const authHeader = req.headers.authorization;
        if (authHeader && authHeader.startsWith('Bearer ')) {
            req.user = {
                id: 'mock-customer-id-001',
                user_type: 'customer'
            };
            return next();
        }
        return res.status(401).json({ error: 'Unauthorized' });
    },
    protect: (req, res, next) => {
        const authHeader = req.headers.authorization;
        if (authHeader && authHeader.startsWith('Bearer ')) {
            req.user = {
                id: 'mock-customer-id-001',
                user_type: 'customer'
            };
            return next();
        }
        return res.status(401).json({ error: 'Unauthorized' });
    }
}));

// Now import routes (after mocks are set up)
const { default: jobRoutes } = await import('../src/routes/jobRoutes.js');

// Create test app
const app = express();
app.use(express.json());
app.use('/api/jobs', jobRoutes);

describe('Jobs API Unit Tests', () => {

    describe('POST /api/jobs - Create Job', () => {
        it('should require authentication', async () => {
            const res = await request(app)
                .post('/api/jobs')
                .send({
                    service_id: 'test-service-id',
                    lat: 24.7136,
                    lng: 46.6753,
                    address_text: 'Test Address'
                });

            expect(res.status).toBe(401);
        });

        it('should create job with valid token', async () => {
            const res = await request(app)
                .post('/api/jobs')
                .set('Authorization', 'Bearer mock-token')
                .send({
                    service_id: 'test-service-id',
                    lat: 24.7136,
                    lng: 46.6753,
                    address_text: 'Test Address',
                    initial_price: 100
                });

            // Might be 201 or 200 depending on implementation
            expect([200, 201]).toContain(res.status);
        });
    });

    describe('GET /api/jobs/:id - Get Job', () => {
        it('should return job details with auth', async () => {
            const res = await request(app)
                .get('/api/jobs/mock-job-id')
                .set('Authorization', 'Bearer mock-token');

            expect(res.status).toBe(200);
        });
    });
});
