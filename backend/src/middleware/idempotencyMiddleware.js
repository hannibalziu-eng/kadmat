import crypto from 'crypto';
import { idempotencyService } from '../services/idempotencyService.js';
import { featureFlags } from '../config/featureFlags.js';
import { responseFormatter, ERROR_CODES, HTTP_STATUS } from '../utils/responseFormatter.js';
import { recordIdempotencyEvent } from '../metrics/jobFlowMetrics.js';
import logger from '../utils/logger.js';

function normalizeIdempotencyKey(req) {
  const value = req.get('X-Idempotency-Key') || req.get('x-idempotency-key') || '';
  return String(value).trim();
}

function buildEndpointScope(req) {
  return `${req.baseUrl}${req.path}`;
}

function hashRequestPayload(payload) {
  const normalized = payload == null ? '' : JSON.stringify(payload);
  return crypto.createHash('sha256').update(normalized).digest('hex');
}

function sendIdempotencyError(res, code, message, statusCode, details = undefined) {
  const formatted = responseFormatter.error(code, message, { statusCode, details });
  return res.status(formatted.statusCode).json(formatted.response);
}

export function requireIdempotencyKey(options = {}) {
  const ttlHours = options.ttlHours || featureFlags.idempotencyTtlHours || 48;

  return async (req, res, next) => {
    const key = normalizeIdempotencyKey(req);
    const endpoint = buildEndpointScope(req);

    if (!key) {
      return sendIdempotencyError(
        res,
        ERROR_CODES.IDEMPOTENCY_KEY_REQUIRED,
        'X-Idempotency-Key header is required',
        HTTP_STATUS.BAD_REQUEST
      );
    }

    if (key.length > 128) {
      return sendIdempotencyError(
        res,
        ERROR_CODES.VALIDATION_FAILED,
        'X-Idempotency-Key is too long',
        HTTP_STATUS.BAD_REQUEST,
        { field: 'X-Idempotency-Key', maxLength: 128 }
      );
    }

    if (!req.user?.id) {
      return sendIdempotencyError(
        res,
        ERROR_CODES.UNAUTHORIZED,
        'Unauthorized',
        HTTP_STATUS.FORBIDDEN
      );
    }

    const requestHash = hashRequestPayload(req.body);
    const metricEndpoint = endpoint.replace(/[0-9a-f]{8}-[0-9a-f-]{27}/gi, ':id');

    try {
      const beginResult = await idempotencyService.begin({
        userId: req.user.id,
        endpoint,
        key,
        requestHash,
        ttlHours,
      });

      if (beginResult.kind === 'existing') {
        const existing = beginResult.record;
        if (existing.request_hash && existing.request_hash !== requestHash) {
          recordIdempotencyEvent(metricEndpoint, 'payload_mismatch');
          return sendIdempotencyError(
            res,
            ERROR_CODES.IDEMPOTENCY_PAYLOAD_MISMATCH,
            'Idempotency key already used with a different payload',
            HTTP_STATUS.CONFLICT
          );
        }

        if (
          existing.status === 'completed' &&
          existing.response_status != null &&
          existing.response_body != null
        ) {
          recordIdempotencyEvent(metricEndpoint, 'replayed');
          res.setHeader('X-Idempotency-Replayed', 'true');
          return res.status(existing.response_status).json(existing.response_body);
        }

        recordIdempotencyEvent(metricEndpoint, 'in_progress');
        return sendIdempotencyError(
          res,
          ERROR_CODES.IDEMPOTENCY_IN_PROGRESS,
          'Similar request is already being processed',
          HTTP_STATUS.CONFLICT
        );
      }

      recordIdempotencyEvent(metricEndpoint, 'created');
      const recordId = beginResult.record?.id;
      const originalJson = res.json.bind(res);
      let persisted = false;

      res.json = (body) => {
        if (!persisted && recordId) {
          persisted = true;
          idempotencyService
            .complete({
              recordId,
              statusCode: res.statusCode || HTTP_STATUS.OK,
              responseBody: body,
            })
            .then(() => {
              recordIdempotencyEvent(metricEndpoint, 'completed');
            })
            .catch((persistError) => {
              logger.error('❌ [Idempotency] Failed to persist response:', persistError);
              recordIdempotencyEvent(metricEndpoint, 'persist_failed');
            });
        }
        return originalJson(body);
      };

      return next();
    } catch (error) {
      const message = error?.message || 'Idempotency middleware failure';
      const dbCode = String(error?.dbCode || '');
      const missingTable =
        dbCode === 'PGRST205' || dbCode === '42P01' || /api_idempotency_keys/i.test(message);

      if (missingTable && !featureFlags.idempotencyStrict) {
        logger.warn(
          '⚠️ [Idempotency] Storage not ready. Continuing because FEATURE_IDEMPOTENCY_STRICT=false'
        );
        recordIdempotencyEvent(metricEndpoint, 'storage_unavailable_bypass');
        return next();
      }

      logger.error('❌ [Idempotency] middleware error:', error);
      return sendIdempotencyError(
        res,
        ERROR_CODES.SERVICE_UNAVAILABLE,
        'Idempotency storage unavailable',
        HTTP_STATUS.INTERNAL_SERVER_ERROR
      );
    }
  };
}
