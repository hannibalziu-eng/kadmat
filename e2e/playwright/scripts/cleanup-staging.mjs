import dotenv from 'dotenv';

dotenv.config({ path: '.env' });
dotenv.config({ path: '.env.local' });

function asBool(value, fallback = false) {
  if (!value || !String(value).trim()) return fallback;
  return ['1', 'true', 'yes', 'on'].includes(String(value).trim().toLowerCase());
}

if (!asBool(process.env.E2E_CLEANUP_ON_END, false)) {
  console.log('[Kadmat E2E Cleanup] Skipped (E2E_CLEANUP_ON_END=false).');
  process.exit(0);
}

console.log('[Kadmat E2E Cleanup] No destructive cleanup configured by default.');
console.log('[Kadmat E2E Cleanup] Add project-specific safe cleanup logic if needed.');
