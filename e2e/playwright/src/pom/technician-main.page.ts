import { expect, Page } from '@playwright/test';

export class TechnicianMainPage {
  constructor(private readonly page: Page) {}

  async expectLoaded(): Promise<void> {
    await expect(this.page).toHaveURL(/\/technician\/home$/);
    await expect(this.page.getByText('الرئيسية', { exact: true }).first()).toBeVisible();
  }

  async openRequestsTab(): Promise<void> {
    await this.page.getByText('الطلبات', { exact: true }).first().click();
    await expect(this.page.getByText('الطلبات', { exact: true }).first()).toBeVisible();
  }

  async openWalletTab(): Promise<void> {
    await this.page.getByText('المحفظة', { exact: true }).first().click();
    await expect(this.page.getByText('المحفظة', { exact: true }).first()).toBeVisible();
  }

  async openProfileTab(): Promise<void> {
    await this.page.getByText('حسابي', { exact: true }).first().click();
    await expect(this.page.getByText('حسابي', { exact: true }).first()).toBeVisible();
  }
}
