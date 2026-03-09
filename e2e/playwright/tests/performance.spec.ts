import { test, expect } from '../src/fixtures/test';
import { request } from '@playwright/test';

test.describe('Lightweight Performance Checks', () => {
  test('auth login and my-jobs API stay within acceptable latency', async ({
    envConfig,
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
    const projectName = test.info().project.name;
    const loginBudget = projectName === 'mobile-webkit' ? 10_000 : 4_000;
    const jobsBudget = projectName === 'mobile-webkit' ? 12_000 : 5_000;

    const loginStart = Date.now();
    const loginResponse = await context.post('auth/login', {
      data: {
        email: envConfig.customerEmail,
        password: envConfig.customerPass,
      },
    });
    const loginElapsed = Date.now() - loginStart;

    expect(loginResponse.ok(), 'Login API should return 2xx').toBeTruthy();
    expect(loginElapsed, `Login API is slower than expected for ${projectName}`).toBeLessThan(
      loginBudget,
    );

    const loginBody = (await loginResponse.json()) as { token?: string };
    expect(loginBody.token, 'Login API should return a token').toBeTruthy();

    const jobsStart = Date.now();
    const jobsResponse = await context.get('jobs/my-jobs', {
      headers: { Authorization: `Bearer ${loginBody.token}` },
    });
    const jobsElapsed = Date.now() - jobsStart;

    expect(jobsResponse.ok(), 'my-jobs API should return 2xx').toBeTruthy();
    expect(jobsElapsed, `my-jobs API is slower than expected for ${projectName}`).toBeLessThan(
      jobsBudget,
    );

    await context.dispose();
  });
});
