import type { Page } from '@playwright/test';
import { gotoApp } from './navigation';

export async function supportsSemanticSelectors(page: Page): Promise<boolean> {
  await gotoApp(page, '/welcome', 120_000);
  const count = await page.getByText('إنشاء حساب', { exact: true }).count();
  return count > 0;
}
