import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import morgan from 'morgan';
import dotenv from 'dotenv';

// Import Routes
import authRoutes from './routes/authRoutes.js';
import jobRoutes from './routes/jobRoutes.js';
import walletRoutes from './routes/walletRoutes.js';
import technicianRoutes from './routes/technicianRoutes.js';
import serviceRoutes from './routes/serviceRoutes.js';
import notificationRoutes from './routes/notificationRoutes.js';
import messageRoutes from './routes/messageRoutes.js';

// Import Error Handlers
import { errorHandler, notFoundHandler } from './middleware/errorHandler.js';

// Import Utilities
import logger from './utils/logger.js';
import { sanitizeInput } from './middleware/sanitizeMiddleware.js';

// Import Health Controller
import { healthCheck, livenessProbe, readinessProbe } from './controllers/healthController.js';

// Import Swagger
import { setupSwagger } from './config/swagger.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// =============================================
// Middlewares
// =============================================

// Security Headers
app.use(helmet());

// CORS (Allow requests from your Flutter app/Web)
app.use(cors());

// Logging
app.use(morgan('dev'));

// Body Parser
app.use(express.json());

// Input Sanitization (after body parser)
app.use(sanitizeInput);

// Auth Rate Limiter (stricter for auth endpoints)
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 5, // 5 attempts per window
    skipSuccessfulRequests: true, // Don't count successful requests
    message: {
        success: false,
        message: 'Too many login attempts, please try again after 15 minutes'
    },
    standardHeaders: true,
    legacyHeaders: false
});

// General Rate Limiter (Basic protection against DDoS)
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 500, // Increased limit for development
    message: 'Too many requests from this IP, please try again later.',
    skip: (req) => {
        // Skip rate limiting for location updates which happen frequently
        return req.path === '/api/technician/location' || req.path.includes('/location');
    }
});
app.use(limiter);

// =============================================
// Routes
// =============================================

app.get('/', (req, res) => {
    res.json({
        message: '🚀 Kadmat Backend is Running!',
        timestamp: new Date().toISOString()
    });
});

// Apply auth rate limiter to login/register
app.use('/api/auth/login', authLimiter);
app.use('/api/auth/register', authLimiter);

app.use('/api/auth', authRoutes);
app.use('/api/jobs', jobRoutes);
app.use('/api/wallet', walletRoutes);
app.use('/api/technician', technicianRoutes);
app.use('/api/services', serviceRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/messages', messageRoutes);

// Health Check Endpoints
app.get('/health', healthCheck);
app.get('/health/live', livenessProbe);
app.get('/health/ready', readinessProbe);

// Monitoring Endpoint
import { register } from './config/monitoring.js';
app.get('/metrics', async (req, res) => {
    res.setHeader('Content-Type', register.contentType);
    res.send(await register.metrics());
});

// API Documentation (Swagger)
setupSwagger(app);

// =============================================
// Error Handling
// =============================================

// 404 Handler (must be after all routes)
app.use(notFoundHandler);

// Centralized Error Handler (must be last)
app.use(errorHandler);

// =============================================
// Start Server
// =============================================

import { startJobRetryScheduler } from './jobs/jobRetryScheduler.js';
import { startJobExpiryScheduler } from './jobs/jobExpiryScheduler.js';
import { initializeFirebase } from './services/fcmService.js';

// Export app for testing
export default app;

// Only listen if run directly
if (process.argv[1] === new URL(import.meta.url).pathname) {
    app.listen(PORT, () => {
        logger.info(`🚀 Server listening on port: ${PORT}`);

        // Initialize Firebase for push notifications
        initializeFirebase();

        // Start job retry scheduler
        startJobRetryScheduler();

        // Start job expiry scheduler (for 30-min timeouts)
        startJobExpiryScheduler();
    });
}

