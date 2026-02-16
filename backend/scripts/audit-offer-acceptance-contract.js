import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';

dotenv.config();

const supabaseUrl = process.env.SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !serviceRoleKey) {
  console.error('❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const ZERO_UUID = '00000000-0000-0000-0000-000000000000';

function fail(message) {
  throw new Error(message);
}

function isPostgrestMissingFunction(error) {
  const raw = [
    error?.message,
    error?.details,
    error?.hint,
    error?.code ? `code=${error.code}` : null,
  ]
    .filter(Boolean)
    .join(' | ');
  return error?.code === 'PGRST202' || /function/i.test(raw);
}

async function assertAcceptedBidColumnExists() {
  const { data, error } = await supabase
    .from('jobs')
    .select('id, accepted_bid_id, status')
    .limit(1);

  if (error) {
    const raw = [
      error.message,
      error.details,
      error.hint,
      error.code ? `code=${error.code}` : null,
    ]
      .filter(Boolean)
      .join(' | ');
    fail(`jobs.accepted_bid_id check failed: ${raw}`);
  }

  console.log('✅ jobs.accepted_bid_id column is readable');
  console.log(`ℹ️  sampled rows: ${Array.isArray(data) ? data.length : 0}`);
}

async function assertAcceptOfferRpcContract() {
  const { data, error } = await supabase.rpc('accept_job_offer_atomic', {
    p_job_id: ZERO_UUID,
    p_customer_id: ZERO_UUID,
    p_offer_id: ZERO_UUID,
  });

  if (error) {
    const raw = [
      error.message,
      error.details,
      error.hint,
      error.code ? `code=${error.code}` : null,
    ]
      .filter(Boolean)
      .join(' | ');

    if (isPostgrestMissingFunction(error)) {
      fail(`accept_job_offer_atomic is missing: ${raw}`);
    }
    fail(`accept_job_offer_atomic call failed: ${raw}`);
  }

  if (!data || typeof data !== 'object' || typeof data.success !== 'boolean') {
    fail('accept_job_offer_atomic returned invalid payload');
  }

  if (data.success !== false) {
    fail('accept_job_offer_atomic smoke expected a non-success payload for zero UUIDs');
  }

  const expectedCodes = new Set([
    'JOB_NOT_FOUND',
    'NOT_FOUND',
    'VALIDATION_FAILED',
    'UNAUTHORIZED',
    'INVALID_STATUS_TRANSITION',
  ]);
  if (typeof data.code !== 'string' || !expectedCodes.has(data.code)) {
    fail(
      `accept_job_offer_atomic returned unexpected code: ${JSON.stringify(data)}`,
    );
  }

  console.log('✅ accept_job_offer_atomic contract is available and well-formed');
  console.log(`ℹ️  smoke result: code=${data.code} message="${data.message}"`);
}

async function assertUpdateUserLocationRpcContract() {
  const { error } = await supabase.rpc('update_user_location', {
    p_lat: 24.7136,
    p_lng: 46.6753,
    p_user_id: ZERO_UUID,
  });

  if (!error) {
    console.log('✅ update_user_location RPC executed successfully');
    return;
  }

  const raw = [
    error.message,
    error.details,
    error.hint,
    error.code ? `code=${error.code}` : null,
  ]
    .filter(Boolean)
    .join(' | ');

  if (isPostgrestMissingFunction(error)) {
    fail(`update_user_location is missing: ${raw}`);
  }

  // In smoke mode with ZERO_UUID, a "user not found" error is acceptable and
  // still proves the function exists and runs server-side.
  if (/user not found/i.test(raw)) {
    console.log('✅ update_user_location RPC exists (smoke returned user-not-found as expected)');
    return;
  }

  fail(`update_user_location RPC exists but failed contract check: ${raw}`);
}

async function run() {
  console.log('🔍 Running accept-offer contract audit');
  await assertAcceptedBidColumnExists();
  await assertAcceptOfferRpcContract();
  await assertUpdateUserLocationRpcContract();
  console.log('✅ Accept-offer contract audit passed');
}

run()
  .then(() => process.exit(0))
  .catch((error) => {
    const message = error?.message || String(error);
    console.error('❌ Accept-offer contract audit failed:', message);
    if (message.includes('fetch failed')) {
      console.error(
        'ℹ️  Verify network access and SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY values.',
      );
    }
    process.exit(1);
  });
