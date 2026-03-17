/**
 * Jobs API Tests (Mock-based)
 * Uses mocked Supabase to test API logic without real database
 */

import { jest, describe, it, expect, beforeEach } from '@jest/globals';
import request from 'supertest';
import express from 'express';

let currentJob;
let currentCatalogItems;

// Mock Supabase BEFORE importing routes
jest.unstable_mockModule('../src/config/supabase.js', () => ({
    supabase: {
        auth: {
            getUser: jest.fn(() => ({
                data: { user: { id: 'mock-customer-id-001' } },
                error: null
            }))
        },
        from: jest.fn((table) => ({
            select: jest.fn().mockReturnThis(),
            insert: jest.fn().mockReturnThis(),
            update: jest.fn().mockReturnThis(),
            delete: jest.fn().mockReturnThis(),
            eq: jest.fn().mockReturnThis(),
            in: jest.fn().mockReturnThis(),
            neq: jest.fn().mockReturnThis(),
            is: jest.fn().mockReturnThis(),
            limit: jest.fn(async () => ({
                data: table === 'job_catalog_items' ? currentCatalogItems : [],
                error: null
            })),
            single: jest.fn(() => ({
                data: currentJob,
                error: null
            })),
            maybeSingle: jest.fn(() => ({
                data: table === 'job_catalog_items' ? null : currentJob,
                error: null
            }))
        }))
    },
    supabaseAdmin: {
        rpc: jest.fn(() => Promise.resolve({ data: [], error: null })),
        from: jest.fn((table) => ({
            select: jest.fn().mockReturnThis(),
            insert: jest.fn().mockReturnThis(),
            update: jest.fn().mockReturnThis(),
            delete: jest.fn().mockReturnThis(),
            eq: jest.fn().mockReturnThis(),
            in: jest.fn().mockReturnThis(),
            neq: jest.fn().mockReturnThis(),
            is: jest.fn().mockReturnThis(),
            limit: jest.fn(async () => ({
                data: table === 'job_catalog_items' ? currentCatalogItems : [],
                error: null
            })),
            single: jest.fn(() => ({
                data: currentJob,
                error: null
            })),
            maybeSingle: jest.fn(() => ({
                data: table === 'job_catalog_items' ? null : currentJob,
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
    beforeEach(() => {
        currentJob = {
            id: 'mock-job-id',
            status: 'pending',
            customer_id: 'mock-customer-id-001',
            technician_id: null,
            pricing_mode: 'technician_quote',
            quote_required: true,
            initial_price: 100,
            technician_price: null,
            final_price: null,
            catalog_subtotal: null,
            catalog_item_count: 0,
            pricing_summary: null,
        };
        currentCatalogItems = [];
    });

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

        it('returns fixed-price read fields including catalog items', async () => {
            currentJob = {
                ...currentJob,
                id: 'fixed-job-id',
                pricing_mode: 'catalog_fixed',
                quote_required: false,
                catalog_subtotal: 80,
                catalog_item_count: 2,
                pricing_summary: {
                    pricing_mode: 'catalog_fixed',
                    catalog_subtotal: 80,
                    catalog_item_count: 2,
                    currency_code: 'LYD',
                },
            };
            currentCatalogItems = [
                {
                    id: 'line-1',
                    job_id: 'fixed-job-id',
                    service_catalog_item_id: 'item-1',
                    quantity: 2,
                    line_total: 80,
                },
            ];

            const res = await request(app)
                .get('/api/jobs/fixed-job-id')
                .set('Authorization', 'Bearer mock-token');

            expect(res.status).toBe(200);
            expect(res.body?.data?.job_catalog_items).toHaveLength(1);
            expect(res.body?.data?.pricingContext).toMatchObject({
                pricingMode: 'catalog_fixed',
                quoteRequired: false,
                catalogSubtotal: 80,
                catalogItemCount: 2,
            });
            expect(res.body?.data?.permissions?.canSetPrice).toBe(false);
        });
    });
});
