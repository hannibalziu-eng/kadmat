import { test, expect } from '../src/fixtures/test';
import { CustomerLoginPage } from '../src/pom/customer-login.page';
import { TechnicianPublicProfilePage } from '../src/pom/technician-public-profile.page';
import { supportsSemanticSelectors } from '../src/helpers/ui-capability';

function extractName(payload: unknown): string | undefined {
  if (!payload || typeof payload !== 'object') return undefined;
  const asRecord = payload as Record<string, unknown>;

  const direct = asRecord.full_name;
  if (typeof direct === 'string' && direct.trim()) return direct;

  const user = asRecord.user;
  if (user && typeof user === 'object') {
    const nestedName = (user as Record<string, unknown>).full_name;
    if (typeof nestedName === 'string' && nestedName.trim()) return nestedName;
  }

  const data = asRecord.data;
  if (data && typeof data === 'object') {
    const nested = extractName(data);
    if (nested) return nested;
  }

  return undefined;
}

test.describe('Cross-Page Data Consistency', () => {
  test('technician name in public profile matches backend profile payload', async ({
    page,
    envConfig,
    auth,
    api,
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

    const customerToken = await auth.getCustomerToken();
    const backendProfile = await api.getTechnicianProfile(
      customerToken,
      envConfig.technicianPublicId!,
    );
    const backendName = extractName(backendProfile);

    test.skip(!backendName, 'Could not resolve technician full_name from backend payload.');

    const loginPage = new CustomerLoginPage(page);
    const profilePage = new TechnicianPublicProfilePage(page);

    await loginPage.login(envConfig.customerEmail, envConfig.customerPass);
    await profilePage.goto(envConfig.technicianPublicId!);
    await profilePage.expectLoaded();

    await expect(page.getByText(backendName!, { exact: false })).toBeVisible();
  });
});
