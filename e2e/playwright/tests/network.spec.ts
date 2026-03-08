import { test, expect } from '../src/fixtures/test';
import { emulateNetwork, restoreNetwork } from '../src/helpers/network';
import { CustomerLoginPage } from '../src/pom/customer-login.page';
import { gotoApp } from '../src/helpers/navigation';
import { supportsSemanticSelectors } from '../src/helpers/ui-capability';

test.describe('Offline and Weak Network Resilience', () => {
  test('welcome page remains reachable under 4g/3g emulation', async ({
    page,
    context,
    browserName,
  }) => {
    const uiReady = await supportsSemanticSelectors(page);
    test.skip(
      !uiReady,
      'Flutter Web semantics are not exposed in this runtime; selector-based UI flow skipped.',
    );

    test.skip(browserName !== 'chromium', 'CDP network emulation is Chromium-only.');

    const modes: Array<'4g' | '3g'> = ['4g', '3g'];
    const thresholds: Record<'4g' | '3g', number> = {
      '4g': 12_000,
      '3g': 22_000,
    };

    for (const mode of modes) {
      await emulateNetwork(page, context, mode);
      const startedAt = Date.now();
      await gotoApp(page, '/welcome', 120_000);
      await expect(page.getByText('سوقك للمواهب الاحترافية')).toBeVisible();
      const elapsed = Date.now() - startedAt;
      expect(
        elapsed,
        `Welcome page load under ${mode} exceeded threshold (${thresholds[mode]}ms).`,
      ).toBeLessThan(thresholds[mode]);
    }

    await restoreNetwork(page, context);
  });

  test('app surfaces an error state when profile is loaded offline, then recovers', async ({
    page,
    context,
    browserName,
    envConfig,
  }) => {
    const uiReady = await supportsSemanticSelectors(page);
    test.skip(
      !uiReady,
      'Flutter Web semantics are not exposed in this runtime; selector-based UI flow skipped.',
    );

    test.skip(browserName !== 'chromium', 'CDP network emulation is Chromium-only.');
    test.skip(
      !envConfig.customerEmail || !envConfig.customerPass,
      'Missing CUSTOMER_EMAIL/CUSTOMER_PASS in e2e/playwright/.env',
    );
    test.skip(
      !envConfig.technicianPublicId,
      'Set TECHNICIAN_PUBLIC_ID in e2e/playwright/.env for this scenario.',
    );

    const loginPage = new CustomerLoginPage(page);
    await loginPage.login(envConfig.customerEmail, envConfig.customerPass);

    await emulateNetwork(page, context, 'offline');
    await page.goto(`/technician-profile/${encodeURIComponent(envConfig.technicianPublicId!)}`, {
      waitUntil: 'domcontentloaded',
      timeout: 120_000,
    });

    const offlineError = page.getByText(/تعذر تحميل ملف الفني|تحقق من اتصال الإنترنت|حدث خطأ أثناء تحميل ملف الفني/);
    await expect(offlineError.first()).toBeVisible();

    await restoreNetwork(page, context);
    await page.reload();
    await expect(page.getByText('بروفايل الفني', { exact: true }).first()).toBeVisible();
  });
});
