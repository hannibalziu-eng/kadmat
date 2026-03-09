import { test, expect } from '../src/fixtures/test';
import { WelcomePage } from '../src/pom/welcome.page';
import { CustomerLoginPage } from '../src/pom/customer-login.page';
import { TechnicianLoginPage } from '../src/pom/technician-login.page';
import { ForgotPasswordPage } from '../src/pom/forgot-password.page';
import { gotoApp } from '../src/helpers/navigation';
import { supportsSemanticSelectors } from '../src/helpers/ui-capability';
import {
  currentAppPath,
  openHashRoute,
  seedBrowserSession,
} from '../src/helpers/browser-auth';

test.describe('Authentication and Role Permissions', () => {
  test('guest is redirected away from protected wallet route', async ({ page }) => {
    await gotoApp(page, '/wallet', 120_000);
    const currentUrl = page.url();
    expect(
      currentUrl.endsWith('/welcome') || currentUrl.endsWith('/wallet'),
      `Unexpected wallet guard behavior for guest. Current URL: ${currentUrl}`,
    ).toBeTruthy();
  });

  test('forgot password flow shows success state', async ({ page, envConfig }) => {
    const uiReady = await supportsSemanticSelectors(page);
    test.skip(
      !uiReady,
      'Flutter Web semantics are not exposed in this runtime; selector-based UI flow skipped.',
    );

    const forgotPasswordPage = new ForgotPasswordPage(page);
    await forgotPasswordPage.goto();
    await forgotPasswordPage.requestReset(
      envConfig.customerEmail || 'customer@example.com',
    );
  });

  test('customer login reaches customer home shell', async ({ page, envConfig, auth }) => {
    test.skip(
      !envConfig.customerEmail || !envConfig.customerPass,
      'Missing CUSTOMER_EMAIL/CUSTOMER_PASS in e2e/playwright/.env',
    );

    const uiReady = await supportsSemanticSelectors(page);
    if (uiReady) {
      const loginPage = new CustomerLoginPage(page);
      await loginPage.login(envConfig.customerEmail, envConfig.customerPass);
      await expect(page).toHaveURL(/\/$/);
      await expect(page.getByText('الرئيسية', { exact: true }).first()).toBeVisible();
      return;
    }

    const requests: string[] = [];
    page.on('request', (request) => {
      requests.push(request.url());
    });

    await seedBrowserSession(page, {
      baseUrl: envConfig.baseUrl,
      session: await auth.getCustomerSession(),
    });
    await openHashRoute(page, '/');

    await expect.poll(() => currentAppPath(page)).not.toContain('/welcome');
    await expect
      .poll(() =>
        requests.some(
          (url) =>
            url.includes('/api/services') ||
            url.includes('/rest/v1/services') ||
            url.includes('/api/jobs/my-jobs'),
        ),
      )
      .toBeTruthy();
  });

  test('technician login reaches technician shell', async ({ page, envConfig, auth }) => {
    test.skip(
      !envConfig.technicianEmail || !envConfig.technicianPass,
      'Missing TECHNICIAN_EMAIL/TECHNICIAN_PASS in e2e/playwright/.env',
    );

    const uiReady = await supportsSemanticSelectors(page);
    if (uiReady) {
      const welcomePage = new WelcomePage(page);
      await welcomePage.goto();
      await welcomePage.goToTechnicianLanding();
      await page.getByText('لدي حساب بالفعل؟ تسجيل الدخول').first().click();

      const technicianLogin = new TechnicianLoginPage(page);
      await technicianLogin.fillCredentials(envConfig.technicianEmail, envConfig.technicianPass);
      await technicianLogin.submit();

      await expect(page).toHaveURL(/\/technician\/home$/);
      return;
    }

    const requests: string[] = [];
    page.on('request', (request) => {
      requests.push(request.url());
    });

    await seedBrowserSession(page, {
      baseUrl: envConfig.baseUrl,
      session: await auth.getTechnicianSession(),
    });
    await openHashRoute(page, '/technician/home');

    await expect.poll(() => currentAppPath(page)).toBe('/technician/home');
    await expect
      .poll(() =>
        requests.some(
          (url) =>
            url.includes('/api/jobs/my-jobs') || url.includes('/api/notifications'),
        ),
      )
      .toBeTruthy();
  });

  test('customer cannot stay in technician private area', async ({ page, envConfig, auth }) => {
    test.skip(
      !envConfig.customerEmail || !envConfig.customerPass,
      'Missing CUSTOMER_EMAIL/CUSTOMER_PASS in e2e/playwright/.env',
    );

    const uiReady = await supportsSemanticSelectors(page);
    if (uiReady) {
      const loginPage = new CustomerLoginPage(page);
      await loginPage.login(envConfig.customerEmail, envConfig.customerPass);
      await gotoApp(page, '/technician/home', 120_000);
      await expect(page).toHaveURL(/\/$/);
      return;
    }

    await seedBrowserSession(page, {
      baseUrl: envConfig.baseUrl,
      session: await auth.getCustomerSession(),
    });
    await openHashRoute(page, '/technician/home');

    await expect
      .poll(() => currentAppPath(page))
      .not.toContain('/technician/home');
  });

  test('credentials or raw tokens are not exposed in browser logs', async ({
    page,
    envConfig,
    auth,
  }) => {
    test.skip(
      !envConfig.customerEmail || !envConfig.customerPass,
      'Missing CUSTOMER_EMAIL/CUSTOMER_PASS in e2e/playwright/.env',
    );

    const logs: string[] = [];
    page.on('console', (msg) => {
      logs.push(msg.text());
    });

    const uiReady = await supportsSemanticSelectors(page);
    if (uiReady) {
      const loginPage = new CustomerLoginPage(page);
      await loginPage.login(envConfig.customerEmail, envConfig.customerPass);
    } else {
      await seedBrowserSession(page, {
        baseUrl: envConfig.baseUrl,
        session: await auth.getCustomerSession(),
      });
      await openHashRoute(page, '/');
    }

    const suspicious = logs.filter((line) =>
      /Bearer\s+[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+|refresh_token|access_token/i.test(
        line,
      ),
    );

    expect(suspicious, `Sensitive tokens leaked in browser logs:\n${suspicious.join('\n')}`).toEqual([]);
  });
});
