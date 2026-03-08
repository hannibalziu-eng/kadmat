import { cleanupStagingData } from '../helpers/test-data';

async function globalTeardown(): Promise<void> {
  await cleanupStagingData();
  console.log('[Kadmat E2E] Global teardown completed.');
}

export default globalTeardown;
