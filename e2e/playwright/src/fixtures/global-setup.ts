import { seedStagingData } from '../helpers/test-data';
import { env } from './env';

async function warmFlutterWeb(): Promise<void> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 180_000);
  try {
    const response = await fetch(`${env.baseUrl.replace(/\/$/, '')}/welcome`, {
      method: 'GET',
      signal: controller.signal,
    });
    console.log(
      `[Kadmat E2E] Flutter warmup response: ${response.status} ${response.statusText}`,
    );
  } catch (error) {
    console.warn(`[Kadmat E2E] Flutter warmup skipped/failed: ${String(error)}`);
  } finally {
    clearTimeout(timeout);
  }
}

async function globalSetup(): Promise<void> {
  console.log('[Kadmat E2E] Global setup started.');
  console.log(`[Kadmat E2E] BASE_URL=${env.baseUrl}`);
  console.log(`[Kadmat E2E] API_BASE=${env.apiBase}`);
  await warmFlutterWeb();
  await seedStagingData();
}

export default globalSetup;
