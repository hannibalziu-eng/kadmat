import { client, register } from '../config/monitoring.js';

function getOrCreateCounter(name, help, labelNames = []) {
  const existing = register.getSingleMetric(name);
  if (existing) return existing;

  return new client.Counter({
    name,
    help,
    labelNames,
    registers: [register],
  });
}

function getOrCreateHistogram(name, help, labelNames = [], buckets = undefined) {
  const existing = register.getSingleMetric(name);
  if (existing) return existing;

  return new client.Histogram({
    name,
    help,
    labelNames,
    buckets,
    registers: [register],
  });
}

const acceptOfferRequestsTotal = getOrCreateCounter(
  'job_accept_offer_requests_total',
  'Accept-offer requests grouped by result',
  ['outcome', 'error_code', 'status_code']
);

const acceptOfferDurationSeconds = getOrCreateHistogram(
  'job_accept_offer_duration_seconds',
  'Accept-offer endpoint duration in seconds',
  ['outcome'],
  [0.05, 0.1, 0.2, 0.35, 0.5, 0.75, 1, 2, 5]
);

const idempotencyEventsTotal = getOrCreateCounter(
  'idempotency_events_total',
  'Idempotency middleware events',
  ['endpoint', 'outcome']
);

const staleLockRecoveryTotal = getOrCreateCounter(
  'job_stale_lock_recovery_total',
  'Stale lock recovery outcomes',
  ['outcome', 'status']
);

export function recordAcceptOfferMetric({
  outcome = 'error',
  errorCode = 'none',
  statusCode = 500,
  durationMs = 0,
} = {}) {
  acceptOfferRequestsTotal
    .labels(String(outcome || 'error'), String(errorCode || 'none'), String(statusCode || 500))
    .inc(1);

  const durationSeconds = Math.max(0, Number(durationMs || 0) / 1000);
  acceptOfferDurationSeconds.labels(String(outcome || 'error')).observe(durationSeconds);
}

export function recordIdempotencyEvent(endpoint, outcome) {
  idempotencyEventsTotal.labels(String(endpoint || 'unknown'), String(outcome || 'unknown')).inc(1);
}

export function recordStaleLockRecovery(outcome, status) {
  staleLockRecoveryTotal.labels(String(outcome || 'unknown'), String(status || 'unknown')).inc(1);
}
