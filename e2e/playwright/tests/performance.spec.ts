import { test, expect } from '../src/fixtures/test';
import { request } from '@playwright/test';

test.describe('Lightweight Performance Checks', () => {
  test('auth login and my-jobs API stay within acceptable latency', async ({
    envConfig,
    auth,
  }) => {
    test.skip(
      !envConfig.customerEmail || !envConfig.customerPass,
      'Missing CUSTOMER_EMAIL/CUSTOMER_PASS in e2e/playwright/.env',
    );

    const context = await request.newContext({
      baseURL: envConfig.apiBase.endsWith('/') ? envConfig.apiBase : `${envConfig.apiBase}/`,
      extraHTTPHeaders: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
    });

    // Warm backend connection to reduce first-request jitter before timing assertions.
    await context.get('../health', { failOnStatusCode: false });

    const loginStart = Date.now();
    const loginResponse = await context.post('auth/login', {
      data: {
        email: envConfig.customerEmail,
        password: envConfig.customerPass,
      },
    });
    const loginElapsed = Date.now() - loginStart;

    expect(loginResponse.ok(), 'Login API should return 2xx').toBeTruthy();
    expect(loginElapsed, 'Login API is slower than expected').toBeLessThan(4_000);

    const token = await auth.getCustomerToken();

    const jobsStart = Date.now();
    const jobsResponse = await context.get('jobs/my-jobs', {
      headers: { Authorization: `Bearer ${token}` },
    });
    const jobsElapsed = Date.now() - jobsStart;

    expect(jobsResponse.ok(), 'my-jobs API should return 2xx').toBeTruthy();
    expect(jobsElapsed, 'my-jobs API is slower than expected').toBeLessThan(5_000);

    await context.dispose();
  });
});
