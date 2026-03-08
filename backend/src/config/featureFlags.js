function parseBoolean(value, fallback = false) {
  if (value == null) return fallback;
  const normalized = String(value).trim().toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  return fallback;
}

function parsePositiveInt(value, fallback) {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return parsed;
}

export const featureFlags = {
  walletSystem: parseBoolean(process.env.FEATURE_WALLET_SYSTEM, true),
  priceChange: parseBoolean(process.env.FEATURE_PRICE_CHANGE, true),
  staleLockRecovery: parseBoolean(process.env.FEATURE_STALE_LOCK_RECOVERY, true),
  technicianPenaltyRpc: parseBoolean(process.env.FEATURE_TECHNICIAN_PENALTY_RPC, true),
  idempotencyStrict: parseBoolean(process.env.FEATURE_IDEMPOTENCY_STRICT, true),
  staleLockHours: parsePositiveInt(process.env.STALE_LOCK_HOURS, 6),
  idempotencyTtlHours: parsePositiveInt(process.env.IDEMPOTENCY_TTL_HOURS, 48),
};
