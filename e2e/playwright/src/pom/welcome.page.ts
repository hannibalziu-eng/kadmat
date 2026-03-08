import { expect, Page } from '@playwright/test';
import { gotoApp } from '../helpers/navigation';

export class WelcomePage {
  constructor(private readonly page: Page) {}

  private async open(path: string): Promise<void> {
    await gotoApp(this.page, path, 120_000);
  }

  async goto(): Promise<void> {
    await this.open('/welcome');
    await this.expectLoaded();
  }

  async expectLoaded(): Promise<void> {
    await expect(this.page.getByText('إنشاء حساب', { exact: true }).first()).toBeVisible();
  }

  async goToCustomerLogin(): Promise<void> {
    await this.page.getByText('تسجيل الدخول', { exact: true }).first().click();
    await expect(this.page).toHaveURL(/\/login$/);
  }

  async goToCustomerRegister(): Promise<void> {
    await this.page.getByText('إنشاء حساب', { exact: true }).first().click();
    await expect(this.page).toHaveURL(/\/register$/);
  }

  async goToTechnicianLanding(): Promise<void> {
    await this.page.getByText('هل أنت فني؟ سجل دخولك من هنا').first().click();
    await expect(this.page).toHaveURL(/\/technician\/landing$/);
  }
}
