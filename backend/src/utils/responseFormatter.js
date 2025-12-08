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
    error: (code, message, statusCode = 400) => {
        const response = {
            success: false,
            error: {
                code,
                message
            }
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
    ACCEPT_FAILED: 'ACCEPT_FAILED'
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
