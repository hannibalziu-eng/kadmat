import { supabaseAdmin } from '../config/supabase.js';
import logger from '../utils/logger.js';

/**
 * Advanced Health Check Controller
 * Checks database connectivity and returns system status
 */
export const healthCheck = async (req, res) => {
    const startTime = Date.now();

    const health = {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        version: process.env.npm_package_version || '1.0.0',
        environment: process.env.NODE_ENV || 'development',
        checks: {
            database: 'unknown',
            memory: 'unknown'
        },
        responseTime: null
    };

    // Check Database Connectivity
    try {
        const { data, error } = await supabaseAdmin
            .from('users')
            .select('id')
            .limit(1);

        if (error) {
            health.checks.database = 'unhealthy';
            health.status = 'degraded';
            logger.warn('Health check: Database unhealthy', { error: error.message });
        } else {
            health.checks.database = 'healthy';
        }
    } catch (error) {
        health.checks.database = 'unhealthy';
        health.status = 'degraded';
        logger.error('Health check: Database error', { error: error.message });
    }

    // Check Memory Usage
    const memoryUsage = process.memoryUsage();
    const memoryUsedMB = Math.round(memoryUsage.heapUsed / 1024 / 1024);
    const memoryTotalMB = Math.round(memoryUsage.heapTotal / 1024 / 1024);

    if (memoryUsedMB / memoryTotalMB > 0.9) {
        health.checks.memory = 'warning';
        health.status = health.status === 'healthy' ? 'degraded' : health.status;
        logger.warn('Health check: High memory usage', { usedMB: memoryUsedMB, totalMB: memoryTotalMB });
    } else {
        health.checks.memory = 'healthy';
    }

    // Add memory details
    health.memory = {
        usedMB: memoryUsedMB,
        totalMB: memoryTotalMB,
        percentUsed: Math.round((memoryUsedMB / memoryTotalMB) * 100)
    };

    // Calculate response time
    health.responseTime = `${Date.now() - startTime}ms`;

    // Return appropriate status code
    const statusCode = health.status === 'healthy' ? 200 : 503;
    res.status(statusCode).json(health);
};

/**
 * Simple liveness probe for Kubernetes
 */
export const livenessProbe = (req, res) => {
    res.status(200).json({ status: 'alive' });
};

/**
 * Readiness probe - checks if app is ready to receive traffic
 */
export const readinessProbe = async (req, res) => {
    try {
        // Quick database check
        const { error } = await supabaseAdmin
            .from('users')
            .select('id')
            .limit(1);

        if (error) {
            return res.status(503).json({ status: 'not ready', reason: 'database' });
        }

        res.status(200).json({ status: 'ready' });
    } catch (error) {
        res.status(503).json({ status: 'not ready', reason: error.message });
    }
};
