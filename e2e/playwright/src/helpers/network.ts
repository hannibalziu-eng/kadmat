import type { BrowserContext, Page } from '@playwright/test';

type NetworkPreset = {
  offline: boolean;
  latency: number;
  downloadThroughput: number;
  uploadThroughput: number;
};

const PRESETS: Record<'3g' | '4g' | 'offline', NetworkPreset> = {
  '3g': {
    offline: false,
    latency: 300,
    downloadThroughput: (1.6 * 1024 * 1024) / 8,
    uploadThroughput: (750 * 1024) / 8,
  },
  '4g': {
    offline: false,
    latency: 70,
    downloadThroughput: (9 * 1024 * 1024) / 8,
    uploadThroughput: (3 * 1024 * 1024) / 8,
  },
  offline: {
    offline: true,
    latency: 0,
    downloadThroughput: 0,
    uploadThroughput: 0,
  },
};

async function withCDPSession(page: Page, context: BrowserContext) {
  const cdpSession = await context.newCDPSession(page);
  await cdpSession.send('Network.enable');
  return cdpSession;
}

export async function emulateNetwork(
  page: Page,
  context: BrowserContext,
  mode: '3g' | '4g' | 'offline',
): Promise<void> {
  const preset = PRESETS[mode];
  const cdp = await withCDPSession(page, context);
  await cdp.send('Network.emulateNetworkConditions', preset);
}

export async function restoreNetwork(page: Page, context: BrowserContext): Promise<void> {
  const cdp = await withCDPSession(page, context);
  await cdp.send('Network.emulateNetworkConditions', {
    offline: false,
    latency: 0,
    downloadThroughput: -1,
    uploadThroughput: -1,
  });
}
