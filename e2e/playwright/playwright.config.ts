import { defineConfig, devices } from '@playwright/test';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.resolve(__dirname, '.env') });
dotenv.config({ path: path.resolve(__dirname, '.env.local') });

const baseURL = process.env.BASE_URL || 'http://127.0.0.1:7357';
const artifactsRoot = path.resolve(__dirname, '../../output/playwright');

export default defineConfig({
  testDir: path.resolve(__dirname, 'tests'),
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 1,
  workers: process.env.CI ? 2 : 1,
  timeout: 180_000,
  expect: {
    timeout: 30_000,
  },
  globalSetup: path.resolve(__dirname, 'src/fixtures/global-setup.ts'),
  globalTeardown: path.resolve(__dirname, 'src/fixtures/global-teardown.ts'),
  reporter: [
    ['list'],
    ['html', { outputFolder: path.join(artifactsRoot, 'html-report'), open: 'never' }],
    ['json', { outputFile: path.join(artifactsRoot, 'results.json') }],
  ],
  outputDir: path.join(artifactsRoot, 'test-results'),
  use: {
    baseURL,
    actionTimeout: 15_000,
    navigationTimeout: 120_000,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    testIdAttribute: 'data-testid',
    headless: process.env.HEADED === '1' ? false : true,
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
    {
      name: 'mobile-webkit',
      use: { ...devices['iPhone 14 Pro'] },
    },
  ],
});
