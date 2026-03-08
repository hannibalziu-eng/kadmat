import { test, expect } from '../src/fixtures/test';
import { TechnicianLoginPage } from '../src/pom/technician-login.page';
import { TechnicianMainPage } from '../src/pom/technician-main.page';
import { gotoApp } from '../src/helpers/navigation';
import { supportsSemanticSelectors } from '../src/helpers/ui-capability';

test.describe('Technician Journey', () => {
  test('technician can navigate dashboard tabs and access notifications', async ({
    page,
    envConfig,
  }) => {
    const uiReady = await supportsSemanticSelectors(page);
    test.skip(
      !uiReady,
      'Flutter Web semantics are not exposed in this runtime; selector-based UI flow skipped.',
    );

    test.skip(
      !envConfig.technicianEmail || !envConfig.technicianPass,
      'Missing TECHNICIAN_EMAIL/TECHNICIAN_PASS in e2e/playwright/.env',
    );

    const loginPage = new TechnicianLoginPage(page);
    const mainPage = new TechnicianMainPage(page);

    await loginPage.login(envConfig.technicianEmail, envConfig.technicianPass);
    await mainPage.expectLoaded();

    await mainPage.openRequestsTab();
    await mainPage.openWalletTab();
    await mainPage.openProfileTab();

    await gotoApp(page, '/notifications', 120_000);
    await expect(page.getByText('الإشعارات', { exact: true }).first()).toBeVisible();
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
