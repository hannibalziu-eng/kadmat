import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  NOTIFICATION_TYPE_REGISTRY,
  AUDIENCE_ROLES,
  NOTIFICATION_CATEGORIES,
} from '../src/constants/notificationContract.js';
import { NOTIFICATION_EVENT_POLICY_REGISTRY } from '../src/constants/notificationEventPolicy.js';

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

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const backendRoot = path.resolve(__dirname, '..');

function fail(message) {
  throw new Error(message);
}

async function assertSchemaColumns() {
  const { error } = await supabase
    .from('notifications')
    .select('id,user_id,type,title,body,data,is_read,created_at,audience_role,category,channels,entity_type,entity_id,dedupe_key,priority')
    .limit(1);

  if (error) {
    const details = [error.message, error.details, error.hint, error.code]
      .filter(Boolean)
      .join(' | ');
    fail(`notifications schema check failed: ${details}`);
  }

  console.log('✅ notifications segmentation columns are readable');
}

async function assertNoInvalidContractRows() {
  const validRoles = AUDIENCE_ROLES.join(',');
  const validCategories = NOTIFICATION_CATEGORIES.join(',');

  const { data, error } = await supabase
    .from('notifications')
    .select('id,audience_role,category,priority,channels')
    .or(
      [
        `audience_role.not.in.(${validRoles})`,
        `category.not.in.(${validCategories})`,
        'priority.lt.1',
        'priority.gt.5',
      ].join(',')
    )
    .limit(5);

  if (error) {
    const details = [error.message, error.details, error.hint, error.code]
      .filter(Boolean)
      .join(' | ');
    fail(`invalid-row check failed: ${details}`);
  }

  if ((data || []).length > 0) {
    fail(`found invalid notifications contract rows: ${JSON.stringify(data)}`);
  }

  console.log('✅ no invalid audience/category/priority rows detected');
}

async function assertTypeCoverageFromSource() {
  const files = [
    'src/services/jobService.js',
    'src/services/jobSearchService.js',
    'src/jobs/jobExpiryScheduler.js',
    'src/jobs/staleLockRecoveryScheduler.js',
  ];

  const callRegex = /notifyUsers?\s*\(\s*\{([\s\S]*?)\}\s*\)/g;
  const typeRegex = /\btype:\s*'([^']+)'/;
  const discoveredTypes = new Set();

  for (const relative of files) {
    const content = await fs.readFile(path.join(backendRoot, relative), 'utf8');
    for (const call of content.matchAll(callRegex)) {
      const body = String(call[1] || '');
      const typeMatch = body.match(typeRegex);
      const value = String(typeMatch?.[1] || '').trim();
      if (value) {
        discoveredTypes.add(value);
      }
    }
  }

  const registryTypes = new Set(Object.keys(NOTIFICATION_TYPE_REGISTRY));
  const missing = [...discoveredTypes].filter((item) => !registryTypes.has(item));

  if (missing.length > 0) {
    fail(`notification types missing from registry: ${missing.join(', ')}`);
  }

  console.log(`✅ notification type registry covers ${discoveredTypes.size} source types`);

  const policyTypes = new Set(Object.keys(NOTIFICATION_EVENT_POLICY_REGISTRY));
  const pushTypes = [...discoveredTypes].filter(
    (type) => Array.isArray(NOTIFICATION_TYPE_REGISTRY[type]?.channels)
      && NOTIFICATION_TYPE_REGISTRY[type].channels.includes('push')
  );
  const missingPolicy = pushTypes.filter((type) => !policyTypes.has(type));

  if (missingPolicy.length > 0) {
    fail(`notification policy missing for push-enabled types: ${missingPolicy.join(', ')}`);
  }

  console.log(`✅ notification event policy covers ${pushTypes.length} push-enabled source types`);
}

async function run() {
  console.log('🔍 Running notification contract audit');
  await assertSchemaColumns();
  await assertNoInvalidContractRows();
  await assertTypeCoverageFromSource();
  console.log('✅ Notification contract audit passed');
}

run()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('❌ Notification contract audit failed:', error?.message || String(error));
    process.exit(1);
  });
