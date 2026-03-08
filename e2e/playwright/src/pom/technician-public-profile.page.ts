import { expect, Page } from '@playwright/test';
import { gotoApp } from '../helpers/navigation';

export class TechnicianPublicProfilePage {
  constructor(private readonly page: Page) {}

  async goto(technicianId: string): Promise<void> {
    await gotoApp(
      this.page,
      `/technician-profile/${encodeURIComponent(technicianId)}`,
      120_000,
    );
  }

  async expectLoaded(): Promise<void> {
    await expect(this.page.getByText('بروفايل الفني', { exact: true }).first()).toBeVisible();
  }

  async expectPortfolioSection(): Promise<void> {
    await expect(this.page.getByText('الأعمال السابقة')).toBeVisible();
  }

  async expectStatsSection(): Promise<void> {
    await expect(this.page.getByText('الإحصائيات')).toBeVisible();
  }
}
