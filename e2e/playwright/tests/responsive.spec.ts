import { test, expect } from '../src/fixtures/test';
import { CustomerLoginPage } from '../src/pom/customer-login.page';
import { gotoApp } from '../src/helpers/navigation';
import { supportsSemanticSelectors } from '../src/helpers/ui-capability';

test.describe('Responsive and Cross-Browser Layout', () => {
  test('welcome layout keeps primary actions visible', async ({ page }) => {
    const uiReady = await supportsSemanticSelectors(page);
    test.skip(
      !uiReady,
      'Flutter Web semantics are not exposed in this runtime; selector-based UI flow skipped.',
    );

    await gotoApp(page, '/welcome', 120_000);
    await expect(page.getByText('إنشاء حساب', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('تسجيل الدخول', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('هل أنت فني؟ سجل دخولك من هنا').first()).toBeVisible();
  });

  test('guest session can render customer shell tabs without overflow crashes', async ({ page }) => {
    const uiReady = await supportsSemanticSelectors(page);
    test.skip(
      !uiReady,
      'Flutter Web semantics are not exposed in this runtime; selector-based UI flow skipped.',
    );

    const errors: string[] = [];
    page.on('console', (msg) => {
      const text = msg.text();
      if (/overflowed by|exception|error/i.test(text)) {
        errors.push(text);
      }
    });

    const loginPage = new CustomerLoginPage(page);
    await loginPage.continueAsGuest();

    await expect(page.getByText('الرئيسية', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('الرسائل', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('الطلبات', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('حسابي', { exact: true }).first()).toBeVisible();

    expect(
      errors,
      `Detected potential layout/runtime issues in console:\n${errors.join('\n')}`,
    ).toEqual([]);
  });
});
