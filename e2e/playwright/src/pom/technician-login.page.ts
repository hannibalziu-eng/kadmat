import { expect, Page } from '@playwright/test';
import { gotoApp } from '../helpers/navigation';

export class TechnicianLoginPage {
  constructor(private readonly page: Page) {}

  private async open(path: string): Promise<void> {
    await gotoApp(this.page, path, 120_000);
  }

  async goto(): Promise<void> {
    await this.open('/technician/login');
    await expect(this.page.getByText('تسجيل الدخول', { exact: true }).first()).toBeVisible();
  }

  async fillCredentials(email: string, password: string): Promise<void> {
    const inputs = this.page.locator('input');
    await inputs.nth(0).fill(email);
    await inputs.nth(1).fill(password);
  }

  async submit(): Promise<void> {
    await this.page.getByText('تسجيل الدخول', { exact: true }).first().click();
  }

  async login(email: string, password: string): Promise<void> {
    await this.goto();
    await this.fillCredentials(email, password);
    await this.submit();
  }
}
