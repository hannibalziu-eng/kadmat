import { ERROR_CODES, HTTP_STATUS } from './responseFormatter.js';

const DEFAULT_STATUS_BY_CODE = {
  [ERROR_CODES.VALIDATION_FAILED]: HTTP_STATUS.BAD_REQUEST,
  [ERROR_CODES.INVALID_INPUT]: HTTP_STATUS.BAD_REQUEST,
  [ERROR_CODES.UNAUTHORIZED]: HTTP_STATUS.UNAUTHORIZED,
  [ERROR_CODES.FORBIDDEN]: HTTP_STATUS.FORBIDDEN,
  [ERROR_CODES.NOT_FOUND]: HTTP_STATUS.NOT_FOUND,
  [ERROR_CODES.CONFLICT]: HTTP_STATUS.CONFLICT,
  [ERROR_CODES.JOB_ALREADY_ACCEPTED]: HTTP_STATUS.CONFLICT,
  [ERROR_CODES.DATABASE_ERROR]: HTTP_STATUS.INTERNAL_SERVER_ERROR,
  [ERROR_CODES.SERVER_ERROR]: HTTP_STATUS.INTERNAL_SERVER_ERROR,
  [ERROR_CODES.SERVICE_UNAVAILABLE]: HTTP_STATUS.SERVICE_UNAVAILABLE,
  [ERROR_CODES.RATE_LIMITED]: 429,
};

export class AppError extends Error {
  constructor(
    message,
    {
      statusCode = HTTP_STATUS.INTERNAL_SERVER_ERROR,
      code = ERROR_CODES.SERVER_ERROR,
      details,
    } = {}
  ) {
    super(message);
    this.name = 'AppError';
    this.statusCode = statusCode;
    this.code = code;
    if (details != null) {
      this.details = details;
    }
  }
}

export const createAppError = (message, { statusCode, code, details } = {}) =>
  new AppError(message, {
    statusCode: statusCode ?? DEFAULT_STATUS_BY_CODE[code] ?? HTTP_STATUS.INTERNAL_SERVER_ERROR,
    code: code ?? ERROR_CODES.SERVER_ERROR,
    details,
  });

export const fromJoiError = (error) => {
  const first = error?.details?.[0];
  const field = Array.isArray(first?.path) ? first.path.join('.') : undefined;
  return createAppError(first?.message || 'Invalid request payload', {
    statusCode: HTTP_STATUS.BAD_REQUEST,
    code: ERROR_CODES.VALIDATION_FAILED,
    details: field ? { field } : undefined,
  });
};
