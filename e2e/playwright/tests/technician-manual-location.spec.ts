import { test, expect } from '../src/fixtures/test';
import {
  createSupabaseSession,
  currentAppPath,
  openHashRoute,
  seedBrowserSession,
} from '../src/helpers/browser-auth';

type LoginResponse = {
  token: string;
  user?: {
    id?: string;
  };
};

async function postJson(url: string, body: unknown, token?: string) {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
  const payload = (await response.json().catch(() => ({}))) as Record<string, unknown>;
  return { response, payload };
}

async function fetchServices(apiBase: string) {
  const response = await fetch(`${apiBase}/services`, {
    headers: { Accept: 'application/json' },
  });
  expect(response.ok()).toBeTruthy();
  const payload = (await response.json()) as {
    services?: Array<Record<string, unknown>>;
  };
  return payload.services ?? [];
}

async function registerAndLogin(options: {
  apiBase: string;
  email: string;
  password: string;
  phone: string;
  fullName: string;
  userType: 'customer' | 'technician';
  serviceId?: string;
}) {
  const register = await postJson(`${options.apiBase}/auth/register`, {
    email: options.email,
    password: options.password,
    phone: options.phone,
    full_name: options.fullName,
    user_type: options.userType,
    ...(options.serviceId ? { service_id: options.serviceId } : {}),
  });

  expect(
    register.response.ok(),
    `Register failed: ${register.response.status} ${JSON.stringify(register.payload)}`,
  ).toBeTruthy();

  const login = await postJson(`${options.apiBase}/auth/login`, {
    email: options.email,
    password: options.password,
  });
  expect(
    login.response.ok(),
    `Login failed: ${login.response.status} ${JSON.stringify(login.payload)}`,
  ).toBeTruthy();

  return login.payload as unknown as LoginResponse;
}

test.describe.serial('Technician manual location fallback', () => {
  test('technician can see new jobs after selecting a manual work location', async ({
    browser,
    envConfig,
  }) => {
    const runId = Date.now();
    const password = 'KadmatE2E!123';
    const services = await fetchServices(envConfig.apiBase);
    const firstService = services[0];
    expect(firstService?.id).toBeTruthy();

    const serviceId = String(firstService.id);
    const customerEmail = `manual.customer.${runId}@kadmat.app`;
    const technicianEmail = `manual.tech.${runId}@kadmat.app`;
    const customerName = `عميل يدوي ${runId}`;
    const technicianName = `فني يدوي ${runId}`;

    const customerLogin = await registerAndLogin({
      apiBase: envConfig.apiBase,
      email: customerEmail,
      password,
      phone: `0911${String(runId).slice(-6)}`,
      fullName: customerName,
      userType: 'customer',
    });

    const technicianLogin = await registerAndLogin({
      apiBase: envConfig.apiBase,
      email: technicianEmail,
      password,
      phone: `0922${String(runId).slice(-6)}`,
      fullName: technicianName,
      userType: 'technician',
      serviceId,
    });

    expect(technicianLogin.token).toBeTruthy();

    const online = await postJson(
      `${envConfig.apiBase}/technician/status`,
      { isOnline: true },
      technicianLogin.token,
    );
    expect(
      online.response.ok(),
      `Failed to set technician online: ${online.response.status} ${JSON.stringify(online.payload)}`,
    ).toBeTruthy();

    const createJob = await postJson(
      `${envConfig.apiBase}/jobs`,
      {
        service_id: serviceId,
        lat: 32.8872,
        lng: 13.1913,
        address_text: 'طرابلس - نقطة اختبار يدوية',
        initial_price: 120,
        description: `طلب اختبار ظهور للفني ${runId}`,
      },
      customerLogin.token,
    );
    expect(
      createJob.response.ok(),
      `Failed to create job: ${createJob.response.status} ${JSON.stringify(createJob.payload)}`,
    ).toBeTruthy();

    const technicianSession = await createSupabaseSession({
      email: technicianEmail,
      password,
      supabaseUrl: envConfig.supabaseUrl,
      supabaseAnonKey: envConfig.supabaseAnonKey,
    });

    const context = await browser.newContext({
      viewport: { width: 1440, height: 1100 },
      permissions: [],
    });
    const page = await context.newPage();

    await seedBrowserSession(page, {
      baseUrl: envConfig.baseUrl,
      session: technicianSession,
    });
    await openHashRoute(page, '/technician/home');

    await expect.poll(() => currentAppPath(page)).toBe('/technician/home');
    await page.getByText('الطلبات', { exact: true }).last().click();
    await expect(page.getByText('حدد نطاق عملك يدويًا')).toBeVisible({
      timeout: 30_000,
    });

    await page.getByText('فتح الخريطة', { exact: true }).click();
    const map = page.locator('.leaflet-container').first();
    await expect(map).toBeVisible({ timeout: 30_000 });
    const box = await map.boundingBox();
    expect(box).toBeTruthy();
    await page.mouse.click(box!.x + box!.width / 2, box!.y + box!.height / 2);

    await expect(page.getByText('تم تحديد موقع العمل يدويًا')).toBeVisible({
      timeout: 30_000,
    });
    await expect(page.getByText(customerName)).toBeVisible({ timeout: 30_000 });

    await context.close();
  });
});
