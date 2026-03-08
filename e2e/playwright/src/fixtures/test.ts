import { test as base, expect } from '@playwright/test';
import { env, type KadmatEnv } from './env';
import { KadmatApiClient } from '../helpers/api-client';

type AuthHelpers = {
  getCustomerToken: () => Promise<string>;
  getTechnicianToken: () => Promise<string>;
};

type KadmatFixtures = {
  auth: AuthHelpers;
};

type KadmatWorkerFixtures = {
  envConfig: KadmatEnv;
  api: KadmatApiClient;
};

export const test = base.extend<KadmatFixtures, KadmatWorkerFixtures>({
  envConfig: [
    async ({}, use) => {
      await use(env);
    },
    { scope: 'worker' },
  ],

  api: [
    async ({ envConfig }, use) => {
      const client = new KadmatApiClient(envConfig.apiBase);
      await client.init();
      await use(client);
      await client.dispose();
    },
    { scope: 'worker' },
  ],

  auth: async ({ api, envConfig }, use) => {
    let customerTokenCache: string | undefined;
    let technicianTokenCache: string | undefined;

    async function resolveCustomerToken(): Promise<string> {
      if (customerTokenCache) return customerTokenCache;

      if (envConfig.customerEmail && envConfig.customerPass) {
        try {
          customerTokenCache = await api.login({
            email: envConfig.customerEmail,
            password: envConfig.customerPass,
          });
          return customerTokenCache;
        } catch (error) {
          if (!envConfig.customerToken) {
            throw error;
          }
          customerTokenCache = envConfig.customerToken;
          return customerTokenCache;
        }
      }

      if (envConfig.customerToken) {
        customerTokenCache = envConfig.customerToken;
        return customerTokenCache;
      }

      throw new Error('Missing CUSTOMER_EMAIL/CUSTOMER_PASS or CUSTOMER_TOKEN in E2E env.');
    }

    async function resolveTechnicianToken(): Promise<string> {
      if (technicianTokenCache) return technicianTokenCache;

      if (envConfig.technicianEmail && envConfig.technicianPass) {
        try {
          technicianTokenCache = await api.login({
            email: envConfig.technicianEmail,
            password: envConfig.technicianPass,
          });
          return technicianTokenCache;
        } catch (error) {
          if (!envConfig.technicianToken) {
            throw error;
          }
          technicianTokenCache = envConfig.technicianToken;
          return technicianTokenCache;
        }
      }

      if (envConfig.technicianToken) {
        technicianTokenCache = envConfig.technicianToken;
        return technicianTokenCache;
      }

      throw new Error(
        'Missing TECHNICIAN_EMAIL/TECHNICIAN_PASS or TECHNICIAN_TOKEN in E2E env.',
      );
    }

    const helpers: AuthHelpers = {
      getCustomerToken: resolveCustomerToken,

      getTechnicianToken: resolveTechnicianToken,
    };

    await use(helpers);
  },
});

export { expect };
