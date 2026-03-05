/**
 * Standard Response Formatter for Kadmat API
 * Ensures all endpoints return consistent structure
 */

export const responseFormatter = {
    /**
     * Success response for single item
     */
    success: (data, message = null) => ({
        success: true,
        data,
        ...(message && { message })
    }),

    /**
     * Success response for multiple items with pagination
     */
    successPaginated: (data, pagination = {}) => ({
        success: true,
        data,
        pagination: {
            page: pagination.page || 1,
            limit: pagination.limit || 20,
            total: pagination.total || 0,
            totalPages: pagination.totalPages || 0,
            hasMore: pagination.hasMore || false
        }
    }),

    /**
     * Error response
     */
    error: (code, message, options = 400) => {
        let statusCode = 400;
        let details;
        let requestId;
        let path;

        if (typeof options === 'number') {
            statusCode = options;
        } else if (options && typeof options === 'object') {
            statusCode = options.statusCode ?? statusCode;
            details = options.details;
            requestId = options.requestId;
            path = options.path;
        }

        const response = {
            success: false,
            error: {
                code,
                message,
                ...(details != null && { details }),
                ...(requestId && { requestId })
            },
            timestamp: new Date().toISOString(),
            ...(path && { path })
        };

        return { response, statusCode };
    }
};

// Error codes enum
export const ERROR_CODES = {
    JOB_NOT_FOUND: 'JOB_NOT_FOUND',
    INVALID_STATUS_TRANSITION: 'INVALID_STATUS_TRANSITION',
    UNAUTHORIZED: 'UNAUTHORIZED',
    INVALID_INPUT: 'INVALID_INPUT',
    DATABASE_ERROR: 'DATABASE_ERROR',
    JOB_ALREADY_ACCEPTED: 'JOB_ALREADY_ACCEPTED',
    INSUFFICIENT_PERMISSIONS: 'INSUFFICIENT_PERMISSIONS',
    VALIDATION_FAILED: 'VALIDATION_FAILED',
    ACCEPT_FAILED: 'ACCEPT_FAILED',
    FORBIDDEN: 'FORBIDDEN',
    NOT_FOUND: 'NOT_FOUND',
    CONFLICT: 'CONFLICT',
    ACTIVE_JOB_LOCKED: 'ACTIVE_JOB_LOCKED',
    TECHNICIAN_WALLET_DEBT_LOCKED: 'TECHNICIAN_WALLET_DEBT_LOCKED',
    SERVER_ERROR: 'SERVER_ERROR',
    RATE_LIMITED: 'RATE_LIMITED',
    SERVICE_UNAVAILABLE: 'SERVICE_UNAVAILABLE'
};

// HTTP status codes mapping
export const HTTP_STATUS = {
    OK: 200,
    CREATED: 201,
    BAD_REQUEST: 400,
    UNAUTHORIZED: 401,
    FORBIDDEN: 403,
    NOT_FOUND: 404,
    CONFLICT: 409,
    INTERNAL_SERVER_ERROR: 500
};
