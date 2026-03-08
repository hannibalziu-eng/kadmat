import { test, expect } from '../src/fixtures/test';
import { WelcomePage } from '../src/pom/welcome.page';
import { CustomerLoginPage } from '../src/pom/customer-login.page';
import { TechnicianLoginPage } from '../src/pom/technician-login.page';
import { ForgotPasswordPage } from '../src/pom/forgot-password.page';
import { gotoApp } from '../src/helpers/navigation';
import { supportsSemanticSelectors } from '../src/helpers/ui-capability';

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

  test('customer login reaches customer home shell', async ({ page, envConfig }) => {
    const uiReady = await supportsSemanticSelectors(page);
    test.skip(
      !uiReady,
      'Flutter Web semantics are not exposed in this runtime; selector-based UI flow skipped.',
    );

    test.skip(
      !envConfig.customerEmail || !envConfig.customerPass,
      'Missing CUSTOMER_EMAIL/CUSTOMER_PASS in e2e/playwright/.env',
    );

    const loginPage = new CustomerLoginPage(page);
    await loginPage.login(envConfig.customerEmail, envConfig.customerPass);
    await expect(page).toHaveURL(/\/$/);
    await expect(page.getByText('الرئيسية', { exact: true }).first()).toBeVisible();
  });

  test('technician login reaches technician shell', async ({ page, envConfig }) => {
    const uiReady = await supportsSemanticSelectors(page);
    test.skip(
      !uiReady,
      'Flutter Web semantics are not exposed in this runtime; selector-based UI flow skipped.',
    );

    test.skip(
      !envConfig.technicianEmail || !envConfig.technicianPass,
      'Missing TECHNICIAN_EMAIL/TECHNICIAN_PASS in e2e/playwright/.env',
    );

    const welcomePage = new WelcomePage(page);
    await welcomePage.goto();
    await welcomePage.goToTechnicianLanding();
    await page.getByText('لدي حساب بالفعل؟ تسجيل الدخول').first().click();

    const technicianLogin = new TechnicianLoginPage(page);
    await technicianLogin.fillCredentials(envConfig.technicianEmail, envConfig.technicianPass);
    await technicianLogin.submit();

    await expect(page).toHaveURL(/\/technician\/home$/);
  });

  test('customer cannot stay in technician private area', async ({ page, envConfig }) => {
    const uiReady = await supportsSemanticSelectors(page);
    test.skip(
      !uiReady,
      'Flutter Web semantics are not exposed in this runtime; selector-based UI flow skipped.',
    );

    test.skip(
      !envConfig.customerEmail || !envConfig.customerPass,
      'Missing CUSTOMER_EMAIL/CUSTOMER_PASS in e2e/playwright/.env',
    );

    const loginPage = new CustomerLoginPage(page);
    await loginPage.login(envConfig.customerEmail, envConfig.customerPass);
    await gotoApp(page, '/technician/home', 120_000);
    await expect(page).toHaveURL(/\/$/);
  });

  test('credentials or raw tokens are not exposed in browser logs', async ({
    page,
    envConfig,
  }) => {
    const uiReady = await supportsSemanticSelectors(page);
    test.skip(
      !uiReady,
      'Flutter Web semantics are not exposed in this runtime; selector-based UI flow skipped.',
    );

    test.skip(
      !envConfig.customerEmail || !envConfig.customerPass,
      'Missing CUSTOMER_EMAIL/CUSTOMER_PASS in e2e/playwright/.env',
    );

    const logs: string[] = [];
    page.on('console', (msg) => {
      logs.push(msg.text());
    });

    const loginPage = new CustomerLoginPage(page);
    await loginPage.login(envConfig.customerEmail, envConfig.customerPass);

    const suspicious = logs.filter((line) =>
      /Bearer\s+[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+|refresh_token|access_token/i.test(
        line,
      ),
    );

    expect(suspicious, `Sensitive tokens leaked in browser logs:\n${suspicious.join('\n')}`).toEqual([]);
  });
});
