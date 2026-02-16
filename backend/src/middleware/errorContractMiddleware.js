import crypto from 'crypto';
import { ERROR_CODES } from '../utils/responseFormatter.js';

function inferCode(statusCode) {
    switch (statusCode) {
        case 400:
            return ERROR_CODES.INVALID_INPUT;
        case 401:
            return ERROR_CODES.UNAUTHORIZED;
        case 403:
            return ERROR_CODES.FORBIDDEN;
        case 404:
            return ERROR_CODES.NOT_FOUND;
        case 409:
            return ERROR_CODES.CONFLICT;
        case 429:
            return ERROR_CODES.RATE_LIMITED;
        case 503:
            return ERROR_CODES.SERVICE_UNAVAILABLE;
        default:
            return ERROR_CODES.SERVER_ERROR;
    }
}

function normalizeErrorBody(body, req, statusCode) {
    const base = {
        success: false,
        timestamp: new Date().toISOString(),
        path: req.originalUrl,
    };

    // API already returned a structured contract
    if (body && typeof body === 'object' && body.success === false) {
        if (body.error && typeof body.error === 'object' && !Array.isArray(body.error)) {
            const error = { ...body.error };
            error.code = error.code || inferCode(statusCode);
            error.message = error.message || body.message || 'Request failed';
            error.requestId = error.requestId || req.requestId;

            const details = { ...(error.details && typeof error.details === 'object' ? error.details : {}) };
            if (error.currentStatus && details.currentStatus == null) {
                details.currentStatus = error.currentStatus;
            }
            if (error.attemptedStatus && details.attemptedStatus == null) {
                details.attemptedStatus = error.attemptedStatus;
            }
            if (error.validStates && details.validStates == null) {
                details.validStates = error.validStates;
            }
            if (Object.keys(details).length > 0) {
                error.details = details;
            }

            return {
                ...base,
                error,
                timestamp: body.timestamp || base.timestamp,
                path: body.path || base.path,
            };
        }

        if (typeof body.error === 'string') {
            return {
                ...base,
                error: {
                    code: inferCode(statusCode),
                    message: body.error,
                    requestId: req.requestId,
                },
            };
        }

        if (typeof body.message === 'string') {
            return {
                ...base,
                error: {
                    code: inferCode(statusCode),
                    message: body.message,
                    requestId: req.requestId,
                },
            };
        }
    }

    // Legacy shape: { error: '...' }
    if (body && typeof body === 'object' && typeof body.error === 'string') {
        return {
            ...base,
            error: {
                code: inferCode(statusCode),
                message: body.error,
                requestId: req.requestId,
            },
        };
    }

    // Legacy shape: { message: '...' } with non-2xx status
    if (body && typeof body === 'object' && typeof body.message === 'string') {
        return {
            ...base,
            error: {
                code: inferCode(statusCode),
                message: body.message,
                requestId: req.requestId,
            },
        };
    }

    // Raw error body (string/unknown)
    return {
        ...base,
        error: {
            code: inferCode(statusCode),
            message: typeof body === 'string' ? body : 'Request failed',
            requestId: req.requestId,
        },
    };
}

export const attachRequestContext = (req, res, next) => {
    const requestId = crypto.randomUUID();
    req.requestId = requestId;
    res.setHeader('X-Request-Id', requestId);
    next();
};

export const normalizeErrorResponse = (req, res, next) => {
    const originalJson = res.json.bind(res);

    res.json = (body) => {
        if (res.statusCode >= 400) {
            return originalJson(normalizeErrorBody(body, req, res.statusCode));
        }
        return originalJson(body);
    };

    next();
};
