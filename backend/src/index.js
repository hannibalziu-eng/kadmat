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
    max: 100, // Limit each IP to 100 requests per windowMs
    message: 'Too many requests from this IP, please try again later.'
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

app.listen(PORT, () => {
    console.log(`
  ################################################
  🚀 Server listening on port: ${PORT}
  ################################################
  `);
});
