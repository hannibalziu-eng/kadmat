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

const lowUrgencyTypes = [
  'work_started',
  'job_completed',
  'no_technician',
  'penalty_warning',
  'new_job',
  'completed',
];

async function run() {
  console.log('🔧 Applying notification channel cost policy...');

  const { data, error } = await supabase
    .from('notifications')
    .update({ channels: ['inbox', 'in_app'] })
    .in('type', lowUrgencyTypes)
    .select('id');

  if (error) {
    throw new Error(`Failed to apply channel policy: ${error.message}`);
  }

  console.log(`✅ Updated notification channels for ${data?.length || 0} rows`);
}

run()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('❌ Channel policy update failed:', error?.message || String(error));
    process.exit(1);
  });

