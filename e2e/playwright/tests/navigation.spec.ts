import { test, expect } from '../src/fixtures/test';
import { CustomerLoginPage } from '../src/pom/customer-login.page';
import { CustomerMainPage } from '../src/pom/customer-main.page';
import { CustomerRequestPage } from '../src/pom/customer-request.page';
import { gotoApp } from '../src/helpers/navigation';
import { supportsSemanticSelectors } from '../src/helpers/ui-capability';

test.describe('Customer Navigation and Core Screens', () => {
  test('customer can navigate core bottom tabs', async ({ page, envConfig }) => {
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
    const mainPage = new CustomerMainPage(page);

    await loginPage.login(envConfig.customerEmail, envConfig.customerPass);
    await mainPage.expectLoaded();

    await mainPage.openMessagesTab();
    await mainPage.openOrdersTab();
    await mainPage.openProfileTab();
  });

  test('customer request page is reachable and wired with key form sections', async ({
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

    const loginPage = new CustomerLoginPage(page);
    const requestPage = new CustomerRequestPage(page);

    await loginPage.login(envConfig.customerEmail, envConfig.customerPass);
    await requestPage.goto();
    await requestPage.expectFormSections();
  });

  test('guest access on create-request route is handled gracefully', async ({ page }) => {
    await gotoApp(page, '/customer/create-request', 120_000);
    const currentUrl = page.url();
    if (currentUrl.endsWith('/welcome')) {
      await expect(page).toHaveURL(/\/welcome$/);
      return;
    }

    await expect(page).toHaveURL(/\/customer\/create-request$/);
  });
});
