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

function assertCondition(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function runAudit() {
  console.log('🔍 Running RPC audit: get_nearby_jobs');

  const { data: report, error: reportError } = await supabase.rpc(
    'audit_get_nearby_jobs_rpc'
  );

  if (reportError) {
    throw new Error(`audit_get_nearby_jobs_rpc failed: ${reportError.message}`);
  }

  if (!report || typeof report !== 'object') {
    throw new Error('Audit RPC returned empty/invalid payload');
  }

  console.log('ℹ️  Audit hash status:', {
    current_hash: report.current_hash,
    expected_hash: report.expected_hash,
    hash_matches_expected: report.hash_matches_expected,
  });

  const checks = report.definition_checks || {};
  for (const [name, passed] of Object.entries(checks)) {
    console.log(`${passed ? '✅' : '❌'} ${name}`);
  }

  assertCondition(report.ok === true, 'RPC audit contract check failed');

  // Smoke call to ensure RPC executes successfully with valid params.
  const { data: smokeData, error: smokeError } = await supabase.rpc(
    'get_nearby_jobs',
    {
      technician_lat: 24.7136,
      technician_lng: 46.6753,
      radius_meters: 1000,
      limit_count: 5,
    }
  );

  if (smokeError) {
    throw new Error(`RPC smoke call failed: ${smokeError.message}`);
  }

  if (!Array.isArray(smokeData)) {
    throw new Error('RPC smoke call returned non-array payload');
  }

  const invalidRows = smokeData.filter((row) => {
    if (!row || typeof row !== 'object') return true;
    if (row.technician_id !== null) return true;
    if (!['pending', 'searching', 'no_technician_found'].includes(row.status)) {
      return true;
    }
    return false;
  });

  assertCondition(
    invalidRows.length === 0,
    `RPC returned rows violating visibility contract (${invalidRows.length})`
  );

  console.log('✅ RPC audit passed');
}

runAudit()
  .then(() => process.exit(0))
  .catch((error) => {
    const message = error?.message || String(error);
    console.error('❌ RPC audit failed:', message);
    if (message.includes('fetch failed')) {
      console.error(
        'ℹ️  Verify network access and SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY values.'
      );
    }
    process.exit(1);
  });
