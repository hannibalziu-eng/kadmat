import fs from 'node:fs';
import path from 'node:path';

const baseUrl = process.env.BASE_URL?.trim() || 'http://127.0.0.1:7357';
const apiBase = process.env.API_BASE?.trim() || 'http://127.0.0.1:3000/api';

const customerEmail = process.env.CUSTOMER_EMAIL?.trim() || 'e2e_customer@kadmat.app';
const customerPass = process.env.CUSTOMER_PASS?.trim() || 'KadmatE2E!123';
const technicianEmail = process.env.TECHNICIAN_EMAIL?.trim() || 'e2e_technician@kadmat.app';
const technicianPass = process.env.TECHNICIAN_PASS?.trim() || 'KadmatE2E!123';

async function postJson(url, body) {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify(body),
  });

  let payload = null;
  try {
    payload = await response.json();
  } catch {
    payload = null;
  }

  return { response, payload };
}

function getPayloadMessage(payload) {
  return (
    payload?.message ||
    payload?.error?.message ||
    payload?.error?.details ||
    ''
  );
}

async function ensureUser({ email, password, userType, serviceId }) {
  const registerBody = {
    email,
    password,
    phone: userType === 'technician' ? '0500000002' : '0500000001',
    full_name: userType === 'technician' ? 'فني اختبارات' : 'عميل اختبارات',
    user_type: userType,
    ...(serviceId ? { service_id: serviceId } : {}),
  };

  const { response, payload } = await postJson(`${apiBase}/auth/register`, registerBody);

  if (!response.ok) {
    const message = getPayloadMessage(payload);
    const isDuplicate = /already|exists|registered|duplicate|taken/i.test(message);
    if (!isDuplicate) {
      throw new Error(`Failed to ensure ${userType} user (${email}): ${response.status} ${JSON.stringify(payload)}`);
    }
  }

  const login = await postJson(`${apiBase}/auth/login`, { email, password });
  if (!login.response.ok || !login.payload?.token) {
    throw new Error(`Failed to login ${userType} user (${email}): ${login.response.status} ${JSON.stringify(login.payload)}`);
  }

  return {
    token: login.payload.token,
    userId: login.payload.user?.id,
  };
}

async function getFirstServiceId() {
  const response = await fetch(`${apiBase}/services`, {
    headers: { Accept: 'application/json' },
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch services: ${response.status}`);
  }

  const payload = await response.json();
  const service = payload?.services?.[0];
  return service?.id;
}

async function main() {
  console.log('[bootstrap-local-env] Fetching services...');
  const serviceId = await getFirstServiceId();
  if (!serviceId) {
    throw new Error('No active services found in /api/services.');
  }

  console.log('[bootstrap-local-env] Ensuring customer user...');
  const customer = await ensureUser({
    email: customerEmail,
    password: customerPass,
    userType: 'customer',
  });

  console.log('[bootstrap-local-env] Ensuring technician user...');
  const technician = await ensureUser({
    email: technicianEmail,
    password: technicianPass,
    userType: 'technician',
    serviceId,
  });

  const envText = [
    `BASE_URL=${baseUrl}`,
    `API_BASE=${apiBase}`,
    '',
    `CUSTOMER_EMAIL=${customerEmail}`,
    `CUSTOMER_PASS=${customerPass}`,
    `TECHNICIAN_EMAIL=${technicianEmail}`,
    `TECHNICIAN_PASS=${technicianPass}`,
    '',
    `CUSTOMER_TOKEN=${customer.token || ''}`,
    `TECHNICIAN_TOKEN=${technician.token || ''}`,
    `TECHNICIAN_PUBLIC_ID=${technician.userId || ''}`,
    '',
    'STRICT_REAL_DATA=false',
    'E2E_SEED_ON_START=false',
    'E2E_CLEANUP_ON_END=false',
    '',
  ].join('\n');

  const target = path.resolve(process.cwd(), '.env');
  fs.writeFileSync(target, envText, 'utf8');
  console.log(`[bootstrap-local-env] Wrote ${target}`);
}

await main();
