import { jest, describe, it, expect, beforeAll, afterAll } from '@jest/globals';

import request from 'supertest';
import express from 'express';
import authRoutes from '../src/routes/authRoutes.js';
import jobRoutes from '../src/routes/jobRoutes.js';
import technicianRoutes from '../src/routes/technicianRoutes.js';
import walletRoutes from '../src/routes/walletRoutes.js';

// Mock Supabase
jest.mock('../src/config/supabase.js', () => {
    const mockSupabase = {
        auth: {
            signUp: jest.fn(({ email }) => {
                if (email === 'existing@example.com') return { data: null, error: { message: 'User already exists' } };
                return { data: { user: { id: 'new-user-id' } }, error: null };
            }),
            signInWithPassword: jest.fn(({ email, password }) => {
                if (email === 'wrong@example.com' || password === 'wrongpass') return { data: null, error: { message: 'Invalid credentials' } };
                return { data: { session: { access_token: 'valid-token' }, user: { id: 'test-user-id' } }, error: null };
            }),
            getUser: jest.fn((token) => {
                if (token === 'valid-token') {
                    return { data: { user: { id: 'test-user-id' } }, error: null };
                }
                return { data: { user: null }, error: { message: 'Invalid token' } };
            })
        },
        from: jest.fn(() => ({
            select: jest.fn(() => ({
                eq: jest.fn(() => ({
                    single: jest.fn(() => ({ data: { id: 'test-user-id', wallet: { balance: 100, currency: 'SAR' } }, error: null })),
                    data: [],
                    error: null,
                })),
                single: jest.fn(() => ({ data: { id: 'test-user-id', wallet: { balance: 100, currency: 'SAR' } }, error: null })),
            })),
            insert: jest.fn(() => ({
                select: jest.fn(() => ({
                    single: jest.fn(() => ({ data: { id: 'new-job-id' }, error: null })),
                })),
            })),
            update: jest.fn(() => ({
                eq: jest.fn(() => ({
                    select: jest.fn(() => ({
                        single: jest.fn(() => ({ data: { id: 'job-123', status: 'accepted' }, error: null })),
                    })),
                })),
            })),
        })),
    };

    const mockSupabaseAdmin = {
        auth: {
            admin: {
                createUser: jest.fn(({ email }) => {
                    if (email === 'existing@example.com') return { data: null, error: { message: 'User already exists' } };
                    return { data: { user: { id: 'new-user-id', email: email, user_metadata: {} } }, error: null };
                })
            }
        }
    };

    return {
        supabase: mockSupabase,
        supabaseAdmin: mockSupabaseAdmin
    };
});

// Mock Middleware - use default export
jest.mock('../src/middleware/authMiddleware.js', () => {
    const mockProtect = (req, res, next) => {
        const authHeader = req.headers.authorization;
        if (authHeader && authHeader.startsWith('Bearer ')) {
            const token = authHeader.split(' ')[1];
            if (token === 'valid-token') {
                req.user = { id: 'test-user-id' };
                return next();
            }
        }
        return res.status(401).json({ error: 'Unauthorized' });
    };

    return {
        __esModule: true,
        default: mockProtect,
        protect: mockProtect
    };
});

const app = express();
app.use(express.json());
app.use('/api/auth', authRoutes);
app.use('/api/jobs', jobRoutes);
app.use('/api/technician', technicianRoutes);
app.use('/api/wallet', walletRoutes);

describe('Backend API Tests', () => {
    describe('Auth Routes', () => {
        it('should register a new user successfully', async () => {
            const res = await request(app)
                .post('/api/auth/register')
                .send({
                    email: 'test@example.com',
                    password: 'password123',
                    full_name: 'Test User',
                    user_type: 'customer',
                    phone: '1234567890'
                });
            expect(res.status).toBe(201);
            expect(res.body).toHaveProperty('message');
        });

        it('should fail registration with existing email', async () => {
            const res = await request(app)
                .post('/api/auth/register')
                .send({
                    email: 'existing@example.com',
                    password: 'password123',
                    full_name: 'Test User',
                    user_type: 'customer',
                    phone: '1234567890'
                });
            expect(res.status).toBe(400);
        });

        it('should fail registration with invalid data', async () => {
            const res = await request(app)
                .post('/api/auth/register')
                .send({
                    email: 'invalid-email',
                    password: '123', // Too short
                    phone: '1234567890'
                });
            expect(res.status).toBe(400);
            expect(res.body).toHaveProperty('message');
        });

        it('should login a user successfully', async () => {
            const res = await request(app)
                .post('/api/auth/login')
                .send({
                    email: 'test@example.com',
                    password: 'password123'
                });
            expect(res.status).toBe(200);
            expect(res.body).toHaveProperty('token');
        });

        it('should fail login with wrong credentials', async () => {
            const res = await request(app)
                .post('/api/auth/login')
                .send({
                    email: 'wrong@example.com',
                    password: 'wrongpass'
                });
            expect(res.status).toBe(401);
        });
    });

    describe('Job Routes', () => {
        it('should create a job with valid data', async () => {
            const res = await request(app)
                .post('/api/jobs')
                .set('Authorization', 'Bearer valid-token')
                .send({
                    serviceId: 'service-123',
                    description: 'Fix my sink',
                    latitude: 24.7136,
                    longitude: 46.6753
                });
            expect(res.status).toBe(201);
            expect(res.body).toHaveProperty('id');
        });

        it('should fail to create job without required fields', async () => {
            const res = await request(app)
                .post('/api/jobs')
                .set('Authorization', 'Bearer valid-token')
                .send({
                    description: 'Fix my sink'
                });
            expect(res.status).toBe(400);
        });

        it('should get nearby jobs', async () => {
            const res = await request(app)
                .get('/api/jobs/nearby?latitude=24.7136&longitude=46.6753&radius=10')
                .set('Authorization', 'Bearer valid-token');
            expect(res.status).toBe(200);
        });

        it('should accept a job', async () => {
            const res = await request(app)
                .post('/api/jobs/job-123/accept')
                .set('Authorization', 'Bearer valid-token');
            expect(res.status).toBe(200);
        });

        it('should fail to accept a job without auth', async () => {
            const res = await request(app)
                .post('/api/jobs/job-123/accept')
                .set('Authorization', 'Bearer invalid-token');
            expect(res.status).toBe(401);
        });

        it('should fail to create job without auth token', async () => {
            const res = await request(app)
                .post('/api/jobs')
                .send({
                    serviceId: 'service-123',
                    description: 'Fix my sink',
                    latitude: 24.7136,
                    longitude: 46.6753
                });
            expect(res.status).toBe(401);
        });
    });

    describe('Technician Routes', () => {
        it('should update location', async () => {
            const res = await request(app)
                .post('/api/technician/location')
                .set('Authorization', 'Bearer valid-token')
                .send({
                    latitude: 24.7136,
                    longitude: 46.6753
                });
            expect(res.status).toBe(200);
        });

        it('should fail to update location without auth', async () => {
            const res = await request(app)
                .post('/api/technician/location')
                .send({
                    latitude: 24.7136,
                    longitude: 46.6753
                });
            expect(res.status).toBe(401);
        });
    });

    describe('Wallet Routes', () => {
        it('should get my wallet', async () => {
            const res = await request(app)
                .get('/api/wallet')
                .set('Authorization', 'Bearer valid-token');
            expect(res.status).toBe(200);
        });

        it('should fail to get wallet without auth', async () => {
            const res = await request(app)
                .get('/api/wallet');
            expect(res.status).toBe(401);
        });
    });
});
