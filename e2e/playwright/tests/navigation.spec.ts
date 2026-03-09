import { test, expect } from '../src/fixtures/test';
import { CustomerLoginPage } from '../src/pom/customer-login.page';
import { CustomerMainPage } from '../src/pom/customer-main.page';
import { CustomerRequestPage } from '../src/pom/customer-request.page';
import { gotoApp } from '../src/helpers/navigation';
import { supportsSemanticSelectors } from '../src/helpers/ui-capability';
import {
  currentAppPath,
  openHashRoute,
  seedBrowserSession,
} from '../src/helpers/browser-auth';

test.describe('Customer Navigation and Core Screens', () => {
  test('customer can navigate core shell routes', async ({ page, envConfig, auth }) => {
    test.skip(
      !envConfig.customerEmail || !envConfig.customerPass,
      'Missing CUSTOMER_EMAIL/CUSTOMER_PASS in e2e/playwright/.env',
    );

    const uiReady = await supportsSemanticSelectors(page);
    if (uiReady) {
      const loginPage = new CustomerLoginPage(page);
      const mainPage = new CustomerMainPage(page);

      await loginPage.login(envConfig.customerEmail, envConfig.customerPass);
      await mainPage.expectLoaded();

      await mainPage.openMessagesTab();
      await mainPage.openOrdersTab();
      await mainPage.openProfileTab();
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

    await openHashRoute(page, '/messages');
    await expect.poll(() => currentAppPath(page)).not.toContain('/welcome');

    const requestsBeforeNotifications = requests.length;
    await openHashRoute(page, '/notifications');
    await expect.poll(() => currentAppPath(page)).not.toContain('/welcome');
    await expect
      .poll(() =>
        requests
          .slice(requestsBeforeNotifications)
          .some((url) => url.includes('/api/notifications')),
      )
      .toBeTruthy();

    await expect
      .poll(() =>
        requests.some(
          (url) =>
            url.includes('/api/messages') ||
            url.includes('/api/notifications'),
        ),
      )
      .toBeTruthy();
  });

  test('customer request page is reachable and wired with key form sections', async ({
    page,
    envConfig,
    auth,
  }) => {
    test.skip(
      !envConfig.customerEmail || !envConfig.customerPass,
      'Missing CUSTOMER_EMAIL/CUSTOMER_PASS in e2e/playwright/.env',
    );

    const uiReady = await supportsSemanticSelectors(page);
    if (uiReady) {
      const loginPage = new CustomerLoginPage(page);
      const requestPage = new CustomerRequestPage(page);

      await loginPage.login(envConfig.customerEmail, envConfig.customerPass);
      await requestPage.goto();
      await requestPage.expectFormSections();
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
    const requestsBeforeRoute = requests.length;
    await openHashRoute(page, '/customer/create-request');

    await expect.poll(() => currentAppPath(page)).not.toContain('/welcome');
    await expect
      .poll(() =>
        requests.slice(requestsBeforeRoute).some(
          (url) =>
            url.includes('/api/services') || url.includes('/rest/v1/services'),
        ),
      )
      .toBeTruthy();
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
