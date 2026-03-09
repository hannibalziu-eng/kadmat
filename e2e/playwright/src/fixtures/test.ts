import { test as base, expect } from '@playwright/test';
import { env, type KadmatEnv } from './env';
import { KadmatApiClient } from '../helpers/api-client';
import { createSupabaseSession } from '../helpers/browser-auth';

type AuthHelpers = {
  getCustomerToken: () => Promise<string>;
  getTechnicianToken: () => Promise<string>;
  getCustomerSession: () => Promise<Record<string, unknown>>;
  getTechnicianSession: () => Promise<Record<string, unknown>>;
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
    let customerSessionCache: Record<string, unknown> | undefined;
    let technicianSessionCache: Record<string, unknown> | undefined;

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

    async function resolveCustomerSession(): Promise<Record<string, unknown>> {
      if (customerSessionCache) return customerSessionCache;
      if (!envConfig.customerEmail || !envConfig.customerPass) {
        throw new Error(
          'Missing CUSTOMER_EMAIL/CUSTOMER_PASS for browser session seeding.',
        );
      }
      customerSessionCache = await createSupabaseSession({
        email: envConfig.customerEmail,
        password: envConfig.customerPass,
        supabaseUrl: envConfig.supabaseUrl,
        supabaseAnonKey: envConfig.supabaseAnonKey,
      });
      return customerSessionCache;
    }

    async function resolveTechnicianSession(): Promise<Record<string, unknown>> {
      if (technicianSessionCache) return technicianSessionCache;
      if (!envConfig.technicianEmail || !envConfig.technicianPass) {
        throw new Error(
          'Missing TECHNICIAN_EMAIL/TECHNICIAN_PASS for browser session seeding.',
        );
      }
      technicianSessionCache = await createSupabaseSession({
        email: envConfig.technicianEmail,
        password: envConfig.technicianPass,
        supabaseUrl: envConfig.supabaseUrl,
        supabaseAnonKey: envConfig.supabaseAnonKey,
      });
      return technicianSessionCache;
    }

    const helpers: AuthHelpers = {
      getCustomerToken: resolveCustomerToken,
      getTechnicianToken: resolveTechnicianToken,
      getCustomerSession: resolveCustomerSession,
      getTechnicianSession: resolveTechnicianSession,
    };

    await use(helpers);
  },
});

export { expect };
