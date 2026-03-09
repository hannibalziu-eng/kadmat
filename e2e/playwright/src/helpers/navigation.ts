import { type Page } from '@playwright/test';

async function enableFlutterAccessibilityIfPrompted(page: Page): Promise<void> {
  const accessibilityButton = page.getByRole('button', {
    name: /Enable accessibility/i,
  });

  const isVisible = await accessibilityButton
    .isVisible({ timeout: 20_000 })
    .catch(() => false);

  if (isVisible) {
    await accessibilityButton.evaluate((element) => {
      element.scrollIntoView({ block: 'center' });
      (element as HTMLElement).click();
      return true;
    });
    await accessibilityButton.waitFor({ state: 'hidden', timeout: 20_000 }).catch(() => {});
  }
}

export async function gotoApp(
  page: Page,
  path: string,
  timeout = 120_000,
): Promise<void> {
  await page.goto(path, {
    waitUntil: 'domcontentloaded',
    timeout,
  });

  await enableFlutterAccessibilityIfPrompted(page);
}
