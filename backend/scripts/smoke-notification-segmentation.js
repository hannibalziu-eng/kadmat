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

const ALLOWED_ROLES = new Set(['customer', 'technician', 'admin', 'all']);
const ALLOWED_CATEGORIES = new Set(['job', 'offer', 'payment', 'message', 'system']);

function fail(message) {
  throw new Error(message);
}

async function assertSchemaReady() {
  const { error } = await supabase
    .from('notifications')
    .select('id,user_id,audience_role,category,channels,dedupe_key,priority')
    .limit(1);

  if (error) {
    const details = [error.message, error.details, error.hint, error.code]
      .filter(Boolean)
      .join(' | ');
    fail(`notifications segmentation schema is not ready: ${details}`);
  }

  console.log('✅ schema smoke passed');
}

async function loadRecentNotifications(maxRows = 5000) {
  const pageSize = 1000;
  const allRows = [];
  let from = 0;

  while (from < maxRows) {
    const to = Math.min(from + pageSize - 1, maxRows - 1);
    const { data, error } = await supabase
      .from('notifications')
      .select('id,user_id,audience_role,category,dedupe_key,users!inner(user_type)')
      .order('created_at', { ascending: false })
      .range(from, to);

    if (error) {
      const details = [error.message, error.details, error.hint, error.code]
        .filter(Boolean)
        .join(' | ');
      fail(`failed to fetch notifications for smoke: ${details}`);
    }

    const rows = data || [];
    allRows.push(...rows);

    if (rows.length < pageSize) break;
    from += pageSize;
  }

  return allRows;
}

function findContractViolations(rows) {
  const invalidContractRows = [];
  const audienceMismatches = [];
  const duplicateDedupeKeys = new Map();
  const dedupeSeen = new Map();

  for (const row of rows) {
    if (!ALLOWED_ROLES.has(row.audience_role) || !ALLOWED_CATEGORIES.has(row.category)) {
      invalidContractRows.push({
        id: row.id,
        audience_role: row.audience_role,
        category: row.category,
      });
    }

    const userRole = row.users?.user_type || null;
    if (
      (row.audience_role === 'customer' || row.audience_role === 'technician') &&
      userRole &&
      row.audience_role !== userRole
    ) {
      audienceMismatches.push({
        id: row.id,
        user_id: row.user_id,
        audience_role: row.audience_role,
        user_role: userRole,
      });
    }

    if (row.dedupe_key) {
      const key = String(row.dedupe_key);
      const current = dedupeSeen.get(key) || 0;
      dedupeSeen.set(key, current + 1);
      if (current + 1 > 1) {
        duplicateDedupeKeys.set(key, current + 1);
      }
    }
  }

  return {
    invalidContractRows,
    audienceMismatches,
    duplicateDedupeKeys: [...duplicateDedupeKeys.entries()].map(([key, count]) => ({
      dedupe_key: key,
      count,
    })),
  };
}

async function run() {
  console.log('🔍 Running notification segmentation smoke');

  await assertSchemaReady();
  const rows = await loadRecentNotifications(5000);
  console.log(`ℹ️ scanned notifications: ${rows.length}`);

  const violations = findContractViolations(rows);

  if (violations.invalidContractRows.length > 0) {
    fail(`invalid notification contract rows found: ${JSON.stringify(violations.invalidContractRows.slice(0, 10))}`);
  }

  if (violations.audienceMismatches.length > 0) {
    fail(
      `audience-role leakage detected (role mismatch): ${JSON.stringify(
        violations.audienceMismatches.slice(0, 10)
      )}`
    );
  }

  if (violations.duplicateDedupeKeys.length > 0) {
    fail(
      `duplicate dedupe_key values detected: ${JSON.stringify(
        violations.duplicateDedupeKeys.slice(0, 10)
      )}`
    );
  }

  console.log('✅ notification segmentation smoke passed');
}

run()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('❌ notification segmentation smoke failed:', error?.message || String(error));
    process.exit(1);
  });
