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

function getOrCreateGauge(name, help, labelNames = []) {
  const existing = register.getSingleMetric(name);
  if (existing) return existing;

  return new client.Gauge({
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

const schedulerRunsTotal = getOrCreateCounter(
  'scheduler_runs_total',
  'Scheduler cycles grouped by scheduler and result',
  ['scheduler', 'result']
);

const schedulerSkippedTotal = getOrCreateCounter(
  'scheduler_skipped_total',
  'Skipped scheduler ticks grouped by scheduler and reason',
  ['scheduler', 'reason']
);

const schedulerDurationSeconds = getOrCreateHistogram(
  'scheduler_duration_seconds',
  'Scheduler cycle duration in seconds',
  ['scheduler', 'result'],
  [0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10, 30, 60, 120]
);

const schedulerLastRunTimestamp = getOrCreateGauge(
  'scheduler_last_run_timestamp_seconds',
  'Unix timestamp of last scheduler cycle completion',
  ['scheduler']
);

export function recordSchedulerSkipped(scheduler, reason = 'unknown') {
  schedulerSkippedTotal.labels(String(scheduler || 'unknown'), String(reason || 'unknown')).inc(1);
}

export function recordSchedulerRun({ scheduler, result = 'success', durationMs = 0 } = {}) {
  const safeScheduler = String(scheduler || 'unknown');
  const safeResult = String(result || 'success');
  const durationSeconds = Math.max(0, Number(durationMs || 0) / 1000);

  schedulerRunsTotal.labels(safeScheduler, safeResult).inc(1);
  schedulerDurationSeconds.labels(safeScheduler, safeResult).observe(durationSeconds);
  schedulerLastRunTimestamp.labels(safeScheduler).set(Date.now() / 1000);
}
