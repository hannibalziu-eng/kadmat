import { expect, Page } from '@playwright/test';
import { gotoApp } from '../helpers/navigation';

export class ForgotPasswordPage {
  constructor(private readonly page: Page) {}

  private async open(path: string): Promise<void> {
    await gotoApp(this.page, path, 120_000);
  }

  async goto(): Promise<void> {
    await this.open('/forgot-password');
    await expect(this.page.getByText('إرسال الرابط', { exact: true }).first()).toBeVisible();
  }

  async requestReset(email: string): Promise<void> {
    await this.page.locator('input').first().fill(email);
    await this.page.getByText('إرسال الرابط', { exact: true }).first().click();
    await expect(this.page.getByText('تم إرسال الرابط')).toBeVisible();
  }
}
