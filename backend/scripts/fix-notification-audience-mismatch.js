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

async function fetchMismatches() {
  const pageSize = 1000;
  const allRows = [];
  let from = 0;

  while (true) {
    const to = from + pageSize - 1;
    const { data, error } = await supabase
      .from('notifications')
      .select('id,user_id,audience_role,users!inner(user_type)')
      .in('audience_role', ['customer', 'technician'])
      .order('created_at', { ascending: false })
      .range(from, to);

    if (error) {
      throw new Error(`Failed to load notifications: ${error.message}`);
    }

    const rows = data || [];
    if (rows.length === 0) break;

    for (const row of rows) {
      const userRole = row.users?.user_type;
      if (!userRole) continue;
      if (!['customer', 'technician'].includes(userRole)) continue;
      if (row.audience_role !== userRole) {
        allRows.push({ id: row.id, correctedRole: userRole });
      }
    }

    if (rows.length < pageSize) break;
    from += pageSize;
  }

  return allRows;
}

async function applyFixes(mismatches) {
  let updated = 0;
  for (const row of mismatches) {
    const { error } = await supabase
      .from('notifications')
      .update({ audience_role: row.correctedRole })
      .eq('id', row.id);

    if (error) {
      throw new Error(`Failed updating notification ${row.id}: ${error.message}`);
    }
    updated += 1;
  }
  return updated;
}

async function run() {
  console.log('🔍 Searching notification audience mismatches...');
  const mismatches = await fetchMismatches();
  console.log(`ℹ️ mismatches found: ${mismatches.length}`);

  if (mismatches.length === 0) {
    console.log('✅ No mismatches found. Nothing to fix.');
    return;
  }

  const updated = await applyFixes(mismatches);
  console.log(`✅ Fixed audience_role mismatches: ${updated}`);
}

run()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('❌ Failed to fix notification audience mismatches:', error?.message || String(error));
    process.exit(1);
  });
