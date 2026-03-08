import { expect, Page } from '@playwright/test';
import { gotoApp } from '../helpers/navigation';

export class CustomerRequestPage {
  constructor(private readonly page: Page) {}

  async goto(): Promise<void> {
    await gotoApp(this.page, '/customer/create-request', 120_000);
    await expect(this.page.getByText('طلب خدمة جديدة', { exact: true })).toBeVisible();
  }

  async expectFormSections(): Promise<void> {
    await expect(this.page.getByText('نوع الخدمة')).toBeVisible();
    await expect(this.page.getByText('الموقع')).toBeVisible();
    await expect(this.page.getByText('وصف المشكلة')).toBeVisible();
  }
}
