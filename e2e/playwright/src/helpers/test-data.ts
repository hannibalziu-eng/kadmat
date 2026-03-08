import { env, requiresSeedingConfig } from '../fixtures/env';

const seedTag = '[Kadmat E2E Seed]';

function log(msg: string): void {
  console.log(`${seedTag} ${msg}`);
}

async function supabaseRequest(path: string, init?: RequestInit): Promise<Response> {
  if (!env.supabaseUrl || !env.supabaseServiceRoleKey) {
    throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required for seeding.');
  }

  const normalized = env.supabaseUrl.replace(/\/$/, '');
  return fetch(`${normalized}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: env.supabaseServiceRoleKey,
      Authorization: `Bearer ${env.supabaseServiceRoleKey}`,
      'Content-Type': 'application/json',
      ...(init?.headers || {}),
    },
  });
}

async function upsertServices(): Promise<void> {
  const payload = [
    { name: 'سباكة', name_ar: 'سباكة', is_active: true },
    { name: 'كهرباء', name_ar: 'كهرباء', is_active: true },
    { name: 'تنظيف', name_ar: 'تنظيف', is_active: true },
  ];

  const response = await supabaseRequest('services?on_conflict=name', {
    method: 'POST',
    body: JSON.stringify(payload),
    headers: { Prefer: 'resolution=merge-duplicates' },
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Failed to upsert services: ${response.status} ${text}`);
  }
}

export async function seedStagingData(): Promise<void> {
  if (!env.seedOnStart) {
    log('Skipped seeding (E2E_SEED_ON_START=false).');
    return;
  }

  if (!requiresSeedingConfig()) {
    log('Skipped seeding due to missing Supabase env vars.');
    return;
  }

  log('Seeding active services...');
  await upsertServices();
  log('Seed completed.');
}

export async function cleanupStagingData(): Promise<void> {
  if (!env.cleanupOnEnd) {
    log('Skipped cleanup (E2E_CLEANUP_ON_END=false).');
    return;
  }

  if (!requiresSeedingConfig()) {
    log('Skipped cleanup due to missing Supabase env vars.');
    return;
  }

  // Keep cleanup intentionally conservative to avoid deleting production-like data.
  log('Cleanup is enabled, but no destructive delete is configured by default.');
}
