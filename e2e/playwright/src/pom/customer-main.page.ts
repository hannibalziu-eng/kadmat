import { expect, Page } from '@playwright/test';

export class CustomerMainPage {
  constructor(private readonly page: Page) {}

  async expectLoaded(): Promise<void> {
    await expect(this.page).toHaveURL(/\/$/);
    await expect(this.page.getByText('الرئيسية').first()).toBeVisible();
  }

  async openMessagesTab(): Promise<void> {
    await this.page.getByText('الرسائل', { exact: true }).first().click();
    await expect(this.page.getByText('الرسائل', { exact: true }).first()).toBeVisible();
  }

  async openOrdersTab(): Promise<void> {
    await this.page.getByText('الطلبات', { exact: true }).first().click();
    await expect(this.page.getByText('طلباتي', { exact: true }).first()).toBeVisible();
  }

  async openProfileTab(): Promise<void> {
    await this.page.getByText('حسابي', { exact: true }).first().click();
    await expect(this.page.getByText('حسابي', { exact: true }).first()).toBeVisible();
  }

  async openWalletFromProfile(): Promise<void> {
    await this.openProfileTab();
    await this.page.getByText('المحفظة', { exact: true }).first().click();
    await expect(this.page).toHaveURL(/customer-wallet|wallet/);
  }
}
