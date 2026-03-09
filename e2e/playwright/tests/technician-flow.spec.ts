import { test, expect } from '../src/fixtures/test';
import { TechnicianLoginPage } from '../src/pom/technician-login.page';
import { TechnicianMainPage } from '../src/pom/technician-main.page';
import { gotoApp } from '../src/helpers/navigation';
import { supportsSemanticSelectors } from '../src/helpers/ui-capability';
import {
  currentAppPath,
  openHashRoute,
  seedBrowserSession,
} from '../src/helpers/browser-auth';

test.describe('Technician Journey', () => {
  test('technician can navigate dashboard tabs and access notifications', async ({
    page,
    envConfig,
    auth,
  }) => {
    test.skip(
      !envConfig.technicianEmail || !envConfig.technicianPass,
      'Missing TECHNICIAN_EMAIL/TECHNICIAN_PASS in e2e/playwright/.env',
    );

    const uiReady = await supportsSemanticSelectors(page);
    if (uiReady) {
      const loginPage = new TechnicianLoginPage(page);
      const mainPage = new TechnicianMainPage(page);

      await loginPage.login(envConfig.technicianEmail, envConfig.technicianPass);
      await mainPage.expectLoaded();

      await mainPage.openRequestsTab();
      await mainPage.openWalletTab();
      await mainPage.openProfileTab();

      await gotoApp(page, '/notifications', 120_000);
      await expect(page.getByText('الإشعارات', { exact: true }).first()).toBeVisible();
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
            url.includes('/api/jobs/my-jobs') ||
            url.includes('/api/notifications'),
        ),
      )
      .toBeTruthy();
  });

  test('technician token can access wallet and notifications APIs', async ({
    auth,
    api,
  }) => {
    const token = await auth.getTechnicianToken();

    const wallet = await api.getWallet(token);
    const notifications = await api.getNotifications(token);

    expect(wallet).toBeTruthy();
    expect(notifications).toBeTruthy();
  });
});
