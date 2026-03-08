import dotenv from 'dotenv';

dotenv.config({ path: '.env' });
dotenv.config({ path: '.env.local' });

function asBool(value, fallback = false) {
  if (!value || !String(value).trim()) return fallback;
  return ['1', 'true', 'yes', 'on'].includes(String(value).trim().toLowerCase());
}

const seedEnabled = asBool(process.env.E2E_SEED_ON_START, true);
const supabaseUrl = process.env.SUPABASE_URL?.trim();
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

if (!seedEnabled) {
  console.log('[Kadmat E2E Seed] Skipped (E2E_SEED_ON_START=false).');
  process.exit(0);
}

if (!supabaseUrl || !serviceRoleKey) {
  console.log('[Kadmat E2E Seed] Missing SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY. Nothing changed.');
  process.exit(0);
}

const payload = [
  { name: 'سباكة', name_ar: 'سباكة', is_active: true },
  { name: 'كهرباء', name_ar: 'كهرباء', is_active: true },
  { name: 'تنظيف', name_ar: 'تنظيف', is_active: true },
];

const response = await fetch(`${supabaseUrl.replace(/\/$/, '')}/rest/v1/services?on_conflict=name`, {
  method: 'POST',
  headers: {
    apikey: serviceRoleKey,
    Authorization: `Bearer ${serviceRoleKey}`,
    'Content-Type': 'application/json',
    Prefer: 'resolution=merge-duplicates',
  },
  body: JSON.stringify(payload),
});

if (!response.ok) {
  const text = await response.text();
  console.error(`[Kadmat E2E Seed] Failed: ${response.status} ${text}`);
  process.exit(1);
}

console.log('[Kadmat E2E Seed] Active services upserted successfully.');
