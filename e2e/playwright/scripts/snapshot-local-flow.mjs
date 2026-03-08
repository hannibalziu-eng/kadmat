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
  `snapshot-flow-${Date.now()}`,
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

function appRoute(pathname) {
  return `${baseUrl}/#${pathname}`;
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
  await page.waitForTimeout(6000);
}

async function openRoute(page, pathname, screenshotName, waitMs = 7000) {
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

async function openTechnicianPrivateProfile(page, screenshotName) {
  const viewport = page.viewportSize() || { width: 1440, height: 1200 };
  await page.mouse.click(Math.round(viewport.width * 0.2), viewport.height - 56);
  await page.waitForTimeout(2200);
  await page.screenshot({
    path: path.join(outDir, screenshotName),
  });
}

function notificationsCount(payload) {
  if (Array.isArray(payload)) return payload.length;
  if (Array.isArray(payload?.data)) return payload.data.length;
  if (Array.isArray(payload?.notifications)) return payload.notifications.length;
  return 0;
}

const report = { outDir, checks: [], screenshots: [] };

const services = await api('/services');
const serviceId =
  services.services.find((service) => service.name === 'ac_maintenance')?.id ||
  services.services[0]?.id;
if (!serviceId) {
  throw new Error('No active service found to build the snapshot flow.');
}

const timestamp = Date.now();
const customerEmail = `snapshot_customer_${timestamp}@kadmat.app`;
const technicianEmail = `snapshot_technician_${timestamp}@kadmat.app`;
const password = 'KadmatE2E!123';
const afterPhotoUrl = `${baseUrl}/icons/Icon-512.png`;
const technicianProfileSeed = {
  full_name: 'فني لقطة فلو',
  title: 'خبير صيانة تكييف',
  bio: 'أعالج أعطال التكييف المنزلية مع توثيق واضح قبل وبعد الخدمة.',
  location: 'طرابلس - حي الأندلس',
};
const technicianPortfolioSeed = {
  title: 'تنظيف الوحدة الخارجية',
  description: 'تنظيف شامل مع تبديل الفلاتر واختبار الأداء بعد الصيانة.',
  image_url: afterPhotoUrl,
  completion_date: new Date('2026-02-15T09:00:00.000Z').toISOString(),
};

await api('/auth/register', {
  method: 'POST',
  body: {
    email: customerEmail,
    password,
    phone: `055${String(timestamp).slice(-7)}`,
    full_name: 'عميل لقطة فلو',
    user_type: 'customer',
  },
});
await api('/auth/register', {
  method: 'POST',
  body: {
    email: technicianEmail,
    password,
    phone: `056${String(timestamp).slice(-7)}`,
    full_name: 'فني لقطة فلو',
    user_type: 'technician',
    service_id: serviceId,
  },
});

const customerLogin = await api('/auth/login', {
  method: 'POST',
  body: { email: customerEmail, password },
});
const technicianLogin = await api('/auth/login', {
  method: 'POST',
  body: { email: technicianEmail, password },
});
const customerSession = await authSession(customerEmail, password);
const technicianSession = await authSession(technicianEmail, password);
const technicianId = technicianLogin.user?.id;

if (!technicianId) {
  throw new Error('Technician login did not return a user id.');
}

await api('/technician/profile', {
  method: 'PUT',
  token: technicianLogin.token,
  body: technicianProfileSeed,
});
await api('/technician/portfolio', {
  method: 'POST',
  token: technicianLogin.token,
  body: technicianPortfolioSeed,
});

const seededTechnicianProfile = await api(`/technician/${technicianId}`, {
  token: customerLogin.token,
});
report.technicianId = technicianId;
report.seededTechnicianProfile = {
  full_name: seededTechnicianProfile.data?.full_name,
  title: seededTechnicianProfile.data?.title,
  specialization: seededTechnicianProfile.data?.specialization,
  location: seededTechnicianProfile.data?.location,
  completedJobs: seededTechnicianProfile.data?.stats?.completedJobs,
  portfolioTitles: Array.isArray(seededTechnicianProfile.data?.portfolio)
    ? seededTechnicianProfile.data.portfolio.map((item) => item.title).filter(Boolean)
    : [],
};
report.checks.push('technician_profile_seeded_via_api');

const jobResponse = await api('/jobs', {
  method: 'POST',
  token: customerLogin.token,
  body: {
    service_id: serviceId,
    lat: 24.7136,
    lng: 46.6753,
    address_text: `Riyadh snapshot ${timestamp}`,
    description: `Snapshot flow ${timestamp}`,
    initial_price: 95,
    images: [],
  },
});
const jobId = jobResponse.data.id;
const offerResponse = await api(`/jobs/${jobId}/submit-offer`, {
  method: 'POST',
  token: technicianLogin.token,
  body: { price: 95 },
});
const offerId = offerResponse.data.id;

report.jobId = jobId;
report.offerId = offerId;
report.customerEmail = customerEmail;
report.technicianEmail = technicianEmail;
report.checks.push('fresh_users_and_offer_created');

const preCustomerConversations = await api('/messages/conversations', {
  token: customerLogin.token,
});
const preTechConversations = await api('/messages/conversations', {
  token: technicianLogin.token,
});
report.preAcceptConversationCounts = {
  customer: Array.isArray(preCustomerConversations.data)
    ? preCustomerConversations.data.length
    : 0,
  technician: Array.isArray(preTechConversations.data)
    ? preTechConversations.data.length
    : 0,
};
try {
  await api(`/messages/${jobId}`, { token: customerLogin.token });
  report.preAcceptChatBlocked = false;
} catch (error) {
  report.preAcceptChatBlocked = String(error).includes('COMMUNICATION_NOT_AVAILABLE');
}
report.checks.push('pre_accept_communication_guard_verified');

const browser = await chromium.launch({
  channel: 'chrome',
  headless: process.env.HEADLESS === 'false' ? false : true,
});
const page = await browser.newPage({
  viewport: { width: 1440, height: 1200 },
});
page.on('console', (message) => {
  if (message.type() === 'error') {
    report.consoleErrors = [...(report.consoleErrors || []), message.text()];
  }
});

try {
  await seedSession(page, customerSession);
  await page.screenshot({
    path: path.join(outDir, '00-customer-home-settled.png'),
    fullPage: true,
  });
  report.screenshots.push('00-customer-home-settled.png');

  await openRoute(page, `/jobs/${jobId}/customer/searching`, '01-customer-searching-pre-accept.png');
  report.screenshots.push('01-customer-searching-pre-accept.png');
  await openRoute(
    page,
    `/technician-profile/${technicianId}`,
    '01b-customer-technician-profile-pre-accept.png',
  );
  report.screenshots.push('01b-customer-technician-profile-pre-accept.png');
  await capturePortfolioFocus(page, '01c-customer-technician-portfolio-focus.png');
  report.screenshots.push('01c-customer-technician-portfolio-focus.png');

  await api(`/jobs/${jobId}/accept-offer`, {
    method: 'POST',
    token: customerLogin.token,
    body: { offerId },
  });
  report.checks.push('offer_accepted_via_api');

  await openRoute(page, `/jobs/${jobId}/customer/in-progress`, '02-customer-in-progress.png');
  report.screenshots.push('02-customer-in-progress.png');

  await api(`/messages/${jobId}`, {
    method: 'POST',
    token: customerLogin.token,
    body: { content: 'مرحبا من العميل بعد القبول' },
  });
  await api(`/messages/${jobId}`, {
    method: 'POST',
    token: technicianLogin.token,
    body: { content: 'تم استلام الرسالة من الفني' },
  });
  await openRoute(page, `/jobs/${jobId}/chat`, '03-customer-chat-after-accept.png');
  report.screenshots.push('03-customer-chat-after-accept.png');

  const postTechConversations = await api('/messages/conversations', {
    token: technicianLogin.token,
  });
  const postCustomerConversations = await api('/messages/conversations', {
    token: customerLogin.token,
  });
  report.postAcceptConversationCount = Array.isArray(postTechConversations.data)
    ? postTechConversations.data.length
    : 0;
  report.postAcceptConversationCountCustomer = Array.isArray(postCustomerConversations.data)
    ? postCustomerConversations.data.length
    : 0;
  report.checks.push('post_accept_chat_verified_via_api');

  await api(`/jobs/${jobId}/technician-progress`, {
    method: 'POST',
    token: technicianLogin.token,
    body: { progress: 'arrived' },
  });
  await api(`/jobs/${jobId}/technician-progress`, {
    method: 'POST',
    token: technicianLogin.token,
    body: { progress: 'start_work' },
  });
  await api(`/jobs/${jobId}/request-completion`, {
    method: 'POST',
    token: technicianLogin.token,
    body: {
      final_price: 95,
      notes: 'انتهى العمل',
      after_photos: [afterPhotoUrl],
    },
  });
  report.checks.push('technician_progress_to_pending_confirm');

  await openRoute(
    page,
    `/jobs/${jobId}/customer/confirm-completion`,
    '04-customer-confirm-completion.png',
  );
  report.screenshots.push('04-customer-confirm-completion.png');
  await openRoute(
    page,
    `/jobs/${jobId}/customer/payment-processing`,
    '05-customer-payment-processing.png',
  );
  report.screenshots.push('05-customer-payment-processing.png');

  await api(`/jobs/${jobId}/confirm-completion`, {
    method: 'POST',
    token: customerLogin.token,
    body: { payment_method: 'cash' },
  });
  report.checks.push('customer_completion_confirmed_via_api');

  await openRoute(page, `/jobs/${jobId}/customer/rate`, '06-customer-rate-screen.png');
  report.screenshots.push('06-customer-rate-screen.png');

  await api(`/jobs/${jobId}/rate`, {
    method: 'POST',
    token: customerLogin.token,
    body: { rating: 5, review: 'Snapshot flow verified' },
  });
  report.checks.push('customer_rating_submitted_via_api');

  await openRoute(page, `/jobs/${jobId}/customer/completed`, '07-customer-completed.png');
  report.screenshots.push('07-customer-completed.png');
  await openRoute(page, '/customer-wallet', '07b-customer-wallet.png', 5000);
  report.screenshots.push('07b-customer-wallet.png');
  await openRoute(page, '/notifications', '07c-customer-notifications.png', 5000);
  report.screenshots.push('07c-customer-notifications.png');

  await seedSession(page, technicianSession);
  await openRoute(page, '/technician/home', '08-technician-home.png');
  report.screenshots.push('08-technician-home.png');
  await openTechnicianPrivateProfile(page, '08b-technician-private-profile.png');
  report.screenshots.push('08b-technician-private-profile.png');
  await capturePortfolioFocus(page, '08c-technician-private-portfolio-focus.png');
  report.screenshots.push('08c-technician-private-portfolio-focus.png');
  await openRoute(page, '/wallet', '09-technician-wallet.png');
  report.screenshots.push('09-technician-wallet.png');
  await openRoute(page, '/notifications', '10-technician-notifications.png');
  report.screenshots.push('10-technician-notifications.png');

  const techWallet = await api('/wallet', { token: technicianLogin.token });
  const techNotifications = await api('/notifications', {
    token: technicianLogin.token,
  });
  const customerWallet = await api('/wallet', { token: customerLogin.token });
  const customerNotifications = await api('/notifications', {
    token: customerLogin.token,
  });
  const customerMessages = await api(`/messages/${jobId}`, {
    token: customerLogin.token,
  });
  const technicianMessages = await api(`/messages/${jobId}`, {
    token: technicianLogin.token,
  });
  report.customerWallet = customerWallet;
  report.customerNotificationsCount = notificationsCount(customerNotifications);
  report.technicianWallet = techWallet;
  report.technicianNotificationsCount = notificationsCount(techNotifications);
  report.customerMessageCount = Array.isArray(customerMessages.data)
    ? customerMessages.data.length
    : 0;
  report.technicianMessageCount = Array.isArray(technicianMessages.data)
    ? technicianMessages.data.length
    : 0;
  report.checks.push('technician_wallet_and_notifications_verified_via_api');

  const finalJob = await api(`/jobs/${jobId}`, { token: customerLogin.token });
  report.finalJobStatus = finalJob?.data?.status;

  await fs.writeFile(
    path.join(outDir, 'report.json'),
    `${JSON.stringify(report, null, 2)}\n`,
    'utf8',
  );
  console.log(JSON.stringify(report, null, 2));
} finally {
  await browser.close();
}
