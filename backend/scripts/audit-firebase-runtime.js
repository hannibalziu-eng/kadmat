import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';
import {
    initializeFirebase,
    getFirebaseInitializationStatus,
    sendPushNotification
} from '../src/services/fcmService.js';

dotenv.config();

function fail(message) {
    throw new Error(message);
}

function formatUnknownError(error) {
    if (!error) return 'unknown error';
    if (typeof error === 'string') return error;
    const message = error?.message || '';
    const code = error?.code ? ` code=${error.code}` : '';
    const name = error?.name ? ` name=${error.name}` : '';
    let details = '';
    try {
        details = JSON.stringify(error);
    } catch (_) {
        details = String(error);
    }
    return `${message}${name}${code} details=${details}`.trim();
}

function parseMaybeJson(raw) {
    if (!raw || typeof raw !== 'string') return null;
    try {
        return JSON.parse(raw);
    } catch (_) {
        return null;
    }
}

async function probeRestUsersEndpoint(supabaseUrl, serviceRoleKey) {
    const url = `${supabaseUrl.replace(/\/+$/, '')}/rest/v1/users?select=id&limit=1`;
    const response = await fetch(url, {
        method: 'GET',
        headers: {
            apikey: serviceRoleKey,
            Authorization: `Bearer ${serviceRoleKey}`
        }
    });
    const body = await response.text();
    return {
        status: response.status,
        bodySnippet: body.slice(0, 300)
    };
}

async function queryRestFcmTokenSample(supabaseUrl, serviceRoleKey) {
    const url = `${supabaseUrl.replace(/\/+$/, '')}/rest/v1/users?select=id&fcm_token=not.is.null&limit=5`;
    const response = await fetch(url, {
        method: 'GET',
        headers: {
            apikey: serviceRoleKey,
            Authorization: `Bearer ${serviceRoleKey}`
        }
    });

    const body = await response.text();
    let parsed = null;
    try {
        parsed = JSON.parse(body);
    } catch (_) {
        parsed = null;
    }

    return {
        status: response.status,
        sampleCount: Array.isArray(parsed) ? parsed.length : null,
        bodySnippet: body.slice(0, 300),
        bodyJson: parsed
    };
}

function resolveBoolean(value, fallback = false) {
    if (value == null) return fallback;
    const normalized = String(value).trim().toLowerCase();
    if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
    if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
    return fallback;
}

async function auditSupabaseFcmTokens() {
    const supabaseUrl = process.env.SUPABASE_URL;
    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (!supabaseUrl || !serviceRoleKey) {
        console.log('ℹ️ SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY not set; skipping FCM token DB audit');
        return;
    }

    console.log(`ℹ️ Supabase URL host: ${new URL(supabaseUrl).host}`);
    if (serviceRoleKey.startsWith('sb_secret_')) {
        console.log('ℹ️ Using sb_secret key. If DB audit fails, try legacy service_role JWT key (starts with eyJ...).');
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
        auth: { autoRefreshToken: false, persistSession: false }
    });
    let count = null;
    let countError = null;

    try {
        const result = await supabase
            .from('users')
            .select('*', { count: 'exact', head: true })
            .not('fcm_token', 'is', null);
        count = result.count ?? 0;
        countError = result.error || null;
    } catch (error) {
        countError = error;
    }

    if (!countError) {
        console.log(`✅ users with non-null fcm_token: ${count ?? 0}`);
        return;
    }

    // Fallback path for environments where sb_secret + supabase-js count/head can fail silently.
    let probe = null;
    let sample = null;
    try {
        probe = await probeRestUsersEndpoint(supabaseUrl, serviceRoleKey);
        sample = await queryRestFcmTokenSample(supabaseUrl, serviceRoleKey);
    } catch (probeError) {
        fail(
            `Failed to query users.fcm_token count: ${formatUnknownError(countError)}`
            + ` | rest_probe_error=${formatUnknownError(probeError)}`
        );
    }

    if (probe.status === 200 && sample.status === 200) {
        console.log(
            `⚠️ Supabase count/head failed (${formatUnknownError(countError)}); using REST fallback sample`
        );
        console.log(`✅ users.fcm_token REST sample reachable (sample_count=${sample.sampleCount ?? 0})`);
        return;
    }

    const missingColumnCode = sample?.bodyJson?.code;
    const missingColumnMsg = String(sample?.bodyJson?.message || '');
    if (missingColumnCode === '42703' || missingColumnMsg.toLowerCase().includes('fcm_token')) {
        fail(
            'users.fcm_token column is missing. Apply migration: migrations/36_add_users_fcm_token.sql '
            + '(or migrations/add_fcm_token_users.sql) then rerun audit.'
        );
    }

    fail(
        `Failed to query users.fcm_token count: ${formatUnknownError(countError)}`
        + ` | rest_probe_status=${probe.status} rest_probe_body=${probe.bodySnippet}`
        + ` | fcm_sample_status=${sample.status} fcm_sample_body=${sample.bodySnippet}`
    );
}

async function runPushSmokeIfRequested() {
    const smokeUserId = (process.env.PUSH_SMOKE_USER_ID || '').trim();
    if (!smokeUserId) {
        console.log('ℹ️ PUSH_SMOKE_USER_ID not set; skipping push smoke');
        return;
    }

    const result = await sendPushNotification(smokeUserId, {
        title: 'Kadmat Push Smoke',
        body: 'Firebase runtime smoke test',
        data: {
            type: 'system_maintenance',
            source: 'audit-firebase-runtime'
        },
        priority: 4,
        ttlSeconds: 300,
        collapseKey: 'push_smoke'
    });

    if (!result?.success) {
        fail(`Push smoke failed for user=${smokeUserId}: ${JSON.stringify(result)}`);
    }

    console.log(`✅ Push smoke sent successfully to user=${smokeUserId}`);
}

async function run() {
    console.log('🔍 Firebase runtime audit started');

    initializeFirebase();
    const status = getFirebaseInitializationStatus();

    console.log(
        `ℹ️ Firebase init status: initialized=${status.initialized} hasServiceAccountEnv=${status.hasServiceAccountEnv}`
    );
    if (status.error) {
        console.log(`ℹ️ Firebase init error: ${status.error}`);
    }

    const strictMode = resolveBoolean(process.env.AUDIT_FIREBASE_STRICT, true);
    if (strictMode && !status.initialized) {
        fail('Firebase is not initialized in strict mode');
    }

    await auditSupabaseFcmTokens();
    await runPushSmokeIfRequested();

    console.log('✅ Firebase runtime audit passed');
}

run()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error('❌ Firebase runtime audit failed:', error?.message || String(error));
        process.exit(1);
    });
