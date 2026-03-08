import { test, expect } from '../src/fixtures/test';
import { CustomerLoginPage } from '../src/pom/customer-login.page';
import { CustomerMainPage } from '../src/pom/customer-main.page';
import { TechnicianPublicProfilePage } from '../src/pom/technician-public-profile.page';
import { supportsSemanticSelectors } from '../src/helpers/ui-capability';

test.describe('Customer Journey and Data Integrity', () => {
  test('public technician profile uses live backend data source', async ({
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
    test.skip(
      !envConfig.technicianPublicId,
      'Set TECHNICIAN_PUBLIC_ID in e2e/playwright/.env for this scenario.',
    );

    const requests: string[] = [];
    page.on('request', (request) => {
      requests.push(request.url());
    });

    const loginPage = new CustomerLoginPage(page);
    const profilePage = new TechnicianPublicProfilePage(page);

    await loginPage.login(envConfig.customerEmail, envConfig.customerPass);
    await profilePage.goto(envConfig.technicianPublicId!);
    await profilePage.expectLoaded();

    const expectedApiPath = `/api/technician/${encodeURIComponent(envConfig.technicianPublicId!)}`;
    const hasApiHit = requests.some((url) => url.includes(expectedApiPath));
    const hasSupabaseFallbackHit = requests.some((url) =>
      url.includes('/rest/v1/users') || url.includes('/rest/v1/technician_profiles'),
    );

    const hasLiveDataSource = hasApiHit || hasSupabaseFallbackHit;
    expect(
      hasLiveDataSource,
      'Expected technician profile to be loaded from API/Supabase endpoint, not only static UI.',
    ).toBeTruthy();
  });

  test('messages page should be backed by real messages data (flags mock cards)', async ({
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

    const messageRequests: string[] = [];
    page.on('request', (request) => {
      if (request.url().includes('/api/messages')) {
        messageRequests.push(request.url());
      }
    });

    const loginPage = new CustomerLoginPage(page);
    const mainPage = new CustomerMainPage(page);

    await loginPage.login(envConfig.customerEmail, envConfig.customerPass);
    await mainPage.openMessagesTab();

    const hasKnownMockCards =
      (await page.getByText('سارة أحمد').count()) > 0 &&
      (await page.getByText('يوسف علي').count()) > 0;

    if (hasKnownMockCards && messageRequests.length === 0) {
      const defect =
        'Messages screen appears to use static mock cards without /api/messages network calls.';
      test.info().annotations.push({ type: 'defect', description: defect });
      if (envConfig.strictRealData) {
        expect(messageRequests.length, defect).toBeGreaterThan(0);
      }
    }
  });

  test('customer wallet page should fetch backend wallet data', async ({
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

    const walletRequests: string[] = [];
    page.on('request', (request) => {
      if (request.url().includes('/api/wallet')) {
        walletRequests.push(request.url());
      }
    });

    const loginPage = new CustomerLoginPage(page);
    const mainPage = new CustomerMainPage(page);

    await loginPage.login(envConfig.customerEmail, envConfig.customerPass);
    await mainPage.openWalletFromProfile();

    await expect(page.getByText('المحفظة', { exact: true }).first()).toBeVisible();
    expect(walletRequests.length, 'Expected wallet API calls when opening wallet screen.').toBeGreaterThan(0);
  });
});
