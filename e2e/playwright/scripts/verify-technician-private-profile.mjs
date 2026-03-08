import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const repoRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../..',
);
const baseUrl = (process.env.BASE_URL?.trim() || 'http://127.0.0.1:7361').replace(/\/$/, '');
const apiBase = (process.env.API_BASE?.trim() || 'http://127.0.0.1:3000/api').replace(/\/$/, '');
const supabaseUrl =
  process.env.SUPABASE_URL?.trim() || 'https://wwukyrixgkgagofyrlsq.supabase.co';
const anonKey =
  process.env.SUPABASE_ANON_KEY?.trim() ||
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind3dWt5cml4Z2tnYWdvZnlybHNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ2NzgyMTcsImV4cCI6MjA4MDI1NDIxN30.gELKeHox3dnDMWgaDk9c_KVrvFd-FTtKNuegpogFcwo';
const storageKey =
  process.env.SUPABASE_STORAGE_KEY?.trim() ||
  'sb-wwukyrixgkgagofyrlsq-auth-token';
const outDir = path.join(
  repoRoot,
  'output',
  'playwright',
  `private-profile-${Date.now()}`,
);
await fs.mkdir(outDir, { recursive: true });

async function api(pathname, { method = 'GET', token, body } = {}) {
  const response = await fetch(`${apiBase}${pathname}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  const text = await response.text();
  let payload;
  try {
    payload = JSON.parse(text);
  } catch {
    payload = { raw: text };
  }

  if (!response.ok) {
    throw new Error(
      `${method} ${pathname} failed: ${response.status} ${JSON.stringify(payload)}`,
    );
  }

  return payload;
}

async function authSession(email, password) {
  const response = await fetch(`${supabaseUrl}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: {
      apikey: anonKey,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ email, password }),
  });

  const payload = await response.json();
  if (!response.ok) {
    throw new Error(`Supabase auth failed: ${JSON.stringify(payload)}`);
  }

  return payload;
}

async function enableAccessibilityIfVisible(page) {
  const button = page.getByRole('button', { name: /Enable accessibility/i });
  if (await button.isVisible().catch(() => false)) {
    await button.evaluate((element) => {
      element.scrollIntoView({ block: 'center' });
      element.click();
      return true;
    });
  }
}

async function seedSession(page, session) {
  await page.context().clearCookies();
  await page.goto(`${baseUrl}/?seed=${Date.now()}`, {
    waitUntil: 'domcontentloaded',
  });
  await page.evaluate(() => {
    localStorage.clear();
    sessionStorage.clear();
  });
  await page.addInitScript(
    ({ storageKey: key, session: seededSession }) => {
      localStorage.setItem(key, JSON.stringify(seededSession));
    },
    { storageKey, session },
  );
  await page.goto(`${baseUrl}/`, { waitUntil: 'domcontentloaded' });
  await enableAccessibilityIfVisible(page);
  await page.waitForTimeout(5000);
}

async function openRoute(page, pathname, screenshotName, waitMs = 6000) {
  await page.evaluate((targetPath) => {
    window.location.hash = `#${targetPath}`;
  }, pathname);
  await page.waitForTimeout(waitMs);
  await page.screenshot({
    path: path.join(outDir, screenshotName),
    fullPage: true,
  });
}

async function capturePortfolioFocus(page, screenshotName) {
  const originalViewport = page.viewportSize();
  await page.setViewportSize({ width: 1440, height: 1800 });
  await page.waitForTimeout(1200);
  await page.screenshot({
    path: path.join(outDir, screenshotName),
  });
  if (originalViewport) {
    await page.setViewportSize(originalViewport);
    await page.waitForTimeout(300);
  }
}

async function openPrivateProfileTab(page, screenshotName) {
  const viewport = page.viewportSize() || { width: 1440, height: 1200 };
  await page.mouse.click(Math.round(viewport.width * 0.2), viewport.height - 56);
  await page.waitForTimeout(2200);
  await page.screenshot({
    path: path.join(outDir, screenshotName),
  });
}

const report = { outDir, screenshots: [] };

const services = await api('/services');
const serviceId =
  services.services.find((service) => service.name === 'ac_maintenance')?.id ||
  services.services[0]?.id;
if (!serviceId) {
  throw new Error('No active service found to build the private profile verification.');
}

const timestamp = Date.now();
const technicianEmail = `private_profile_technician_${timestamp}@kadmat.app`;
const password = 'KadmatE2E!123';
const profileSeed = {
  full_name: 'فني الملف الخاص',
  title: 'خبير صيانة تكييف',
  bio: 'هذا الملف الخاص يجب أن يطابق ما يظهر للعميل.',
  location: 'طرابلس - حي الأندلس',
};
const portfolioSeed = {
  title: 'تنظيف الوحدة الخارجية',
  description: 'تنظيف شامل مع تبديل الفلاتر واختبار الأداء بعد الصيانة.',
  image_url: `${baseUrl}/icons/Icon-512.png`,
  completion_date: new Date('2026-02-15T09:00:00.000Z').toISOString(),
};

await api('/auth/register', {
  method: 'POST',
  body: {
    email: technicianEmail,
    password,
    phone: `056${String(timestamp).slice(-7)}`,
    full_name: 'فني الملف الخاص',
    user_type: 'technician',
    service_id: serviceId,
  },
});

const technicianLogin = await api('/auth/login', {
  method: 'POST',
  body: { email: technicianEmail, password },
});
const technicianSession = await authSession(technicianEmail, password);
const technicianId = technicianLogin.user?.id;
if (!technicianId) {
  throw new Error('Technician login did not return a user id.');
}

await api('/technician/profile', {
  method: 'PUT',
  token: technicianLogin.token,
  body: profileSeed,
});
await api('/technician/portfolio', {
  method: 'POST',
  token: technicianLogin.token,
  body: portfolioSeed,
});

const seededProfile = await api(`/technician/${technicianId}`, {
  token: technicianLogin.token,
});
report.technicianId = technicianId;
report.apiProfile = {
  full_name: seededProfile.data?.full_name,
  title: seededProfile.data?.title,
  specialization: seededProfile.data?.specialization,
  location: seededProfile.data?.location,
  portfolioTitles: Array.isArray(seededProfile.data?.portfolio)
    ? seededProfile.data.portfolio.map((item) => item.title).filter(Boolean)
    : [],
  portfolioImageUrl: seededProfile.data?.portfolio?.[0]?.image_url ?? null,
};

const browser = await chromium.launch({
  channel: 'chrome',
  headless: process.env.HEADLESS === 'false' ? false : true,
});
const page = await browser.newPage({
  viewport: { width: 1440, height: 1200 },
});

try {
  await seedSession(page, technicianSession);
  await openRoute(page, '/technician/home', '00-technician-home.png');
  report.screenshots.push('00-technician-home.png');
  await openPrivateProfileTab(page, '01-technician-private-profile.png');
  report.screenshots.push('01-technician-private-profile.png');
  await capturePortfolioFocus(page, '02-technician-private-portfolio-focus.png');
  report.screenshots.push('02-technician-private-portfolio-focus.png');

  await fs.writeFile(
    path.join(outDir, 'report.json'),
    `${JSON.stringify(report, null, 2)}\n`,
    'utf8',
  );
  console.log(JSON.stringify(report, null, 2));
} finally {
  await browser.close();
}
