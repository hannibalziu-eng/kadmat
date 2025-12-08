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

// Import Error Handlers
import { errorHandler, notFoundHandler } from './middleware/errorHandler.js';

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

// Rate Limiting (Basic protection against DDoS)
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

app.use('/api/auth', authRoutes);
app.use('/api/jobs', jobRoutes);
app.use('/api/wallet', walletRoutes);
app.use('/api/technician', technicianRoutes);
app.use('/api/services', serviceRoutes);
app.use('/api/notifications', notificationRoutes);

// Health Check Endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        uptime: process.uptime(),
        timestamp: new Date().toISOString()
    });
});

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

// Export app for testing
export default app;

// Only listen if run directly
if (process.argv[1] === new URL(import.meta.url).pathname) {
    app.listen(PORT, () => {
        console.log(`
      ################################################
      🚀 Server listening on port: ${PORT}
      ################################################
      `);

        // Start job retry scheduler
        startJobRetryScheduler();
    });
}
