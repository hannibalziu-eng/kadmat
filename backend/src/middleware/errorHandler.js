/**
 * Centralized Error Handler Middleware
 * Converts errors into user-friendly messages while preserving technical details for developers
 */

export const errorHandler = (err, req, res, next) => {
    let statusCode = err.statusCode || 500;
    let message = err.message || 'Server error occurred';
    let userMessage = message; // User-friendly message
    let errorCode = 'SERVER_ERROR';

    // PostgreSQL Errors
    if (err.code) {
        switch (err.code) {
            case '22P02': // Invalid UUID format
                statusCode = 400;
                errorCode = 'INVALID_UUID';
                userMessage = 'Invalid ID format provided';
                message = `Invalid UUID: ${err.message}`;
                break;

            case '23505': // Unique violation
                statusCode = 409;
                errorCode = 'DUPLICATE_ENTRY';
                userMessage = 'This record already exists';
                message = `Duplicate entry: ${err.detail || err.message}`;
                break;

            case '23503': // Foreign key violation
                statusCode = 400;
                errorCode = 'INVALID_REFERENCE';
                userMessage = 'Referenced data does not exist';
                message = `Foreign key violation: ${err.detail || err.message}`;
                break;

            case '42501': // RLS policy violation
                statusCode = 403;
                errorCode = 'PERMISSION_DENIED';
                userMessage = 'You do not have permission to perform this action';
                message = `RLS policy violation: ${err.message}`;
                break;

            case 'PGRST116': // PostgREST - no rows
                statusCode = 404;
                errorCode = 'NOT_FOUND';
                userMessage = 'The requested resource was not found';
                message = 'Query returned no results';
                break;

            case 'PGRST205': // PostgREST - table not found
                statusCode = 500;
                errorCode = 'DATABASE_ERROR';
                userMessage = 'A database error occurred. Please try again.';
                message = `Table not found: ${err.message}`;
                break;
        }
    }

    // Joi Validation Errors
    if (err.isJoi) {
        statusCode = 400;
        errorCode = 'VALIDATION_ERROR';
        userMessage = err.details[0].message;
        message = err.details[0].message;
    }

    // Supabase Auth Errors
    if (err.message && err.message.includes('credentials')) {
        statusCode = 401;
        errorCode = 'INVALID_CREDENTIALS';
        userMessage = 'Invalid email or password';
    }

    // Network/Timeout Errors
    if (err.code === 'ETIMEDOUT' || err.code === 'ECONNREFUSED') {
        statusCode = 503;
        errorCode = 'SERVICE_UNAVAILABLE';
        userMessage = 'Service temporarily unavailable. Please try again.';
        message = `Network error: ${err.message}`;
    }

    // Log error for debugging (with full stack trace in development)
    if (process.env.NODE_ENV === 'development') {
        console.error('Error occurred:', {
            errorCode,
            statusCode,
            message,
            stack: err.stack,
            url: req.originalUrl,
            method: req.method,
            body: req.body
        });
    } else {
        console.error('Error:', errorCode, '-', message);
    }

    // Send response
    const response = {
        success: false,
        error: {
            code: errorCode,
            message: userMessage
        }
    };

    // Include technical details in development mode
    if (process.env.NODE_ENV === 'development') {
        response.error.technical = {
            message: message,
            stack: err.stack,
            originalError: err.code || err.name
        };
    }

    res.status(statusCode).json(response);
};

// Not Found Handler (404)
export const notFoundHandler = (req, res, next) => {
    const error = new Error(`Route not found: ${req.method} ${req.originalUrl}`);
    error.statusCode = 404;
    next(error);
};

// Async Error Wrapper (to catch async errors in route handlers)
export const asyncHandler = (fn) => (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
};
