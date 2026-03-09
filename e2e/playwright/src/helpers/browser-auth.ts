import { type Page } from '@playwright/test';
import { gotoApp } from './navigation';

const DEFAULT_SUPABASE_URL = 'https://wwukyrixgkgagofyrlsq.supabase.co';
const DEFAULT_SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind3dWt5cml4Z2tnYWdvZnlybHNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ2NzgyMTcsImV4cCI6MjA4MDI1NDIxN30.gELKeHox3dnDMWgaDk9c_KVrvFd-FTtKNuegpogFcwo';

type SupabaseSession = Record<string, unknown>;

function cleanBaseUrl(value: string): string {
  return value.trim().replace(/\/$/, '');
}

function resolveProjectRef(supabaseUrl: string): string {
  try {
    return new URL(supabaseUrl).hostname.split('.')[0] || 'wwukyrixgkgagofyrlsq';
  } catch {
    return 'wwukyrixgkgagofyrlsq';
  }
}

function isRetriableBootstrapError(error: unknown): boolean {
  if (!(error instanceof Error)) return false;
  const message = error.message.toLowerCase();
  return (
    message.includes('fetch failed') ||
    message.includes('timeout') ||
    message.includes('econnreset') ||
    message.includes('connecttimeouterror') ||
    message.includes('err_connection_closed') ||
    message.includes('503') ||
    message.includes('502') ||
    message.includes('504')
  );
}

function formatBootstrapError(error: unknown): Error {
  if (error instanceof Error) {
    return error;
  }
  return new Error('Supabase session bootstrap failed after retries.');
}

export function resolveSupabaseStorageKey(supabaseUrl?: string): string {
  return `sb-${resolveProjectRef(supabaseUrl || DEFAULT_SUPABASE_URL)}-auth-token`;
}

export async function createSupabaseSession(options: {
  email: string;
  password: string;
  supabaseUrl?: string;
  supabaseAnonKey?: string;
}): Promise<SupabaseSession> {
  const supabaseUrl = (options.supabaseUrl || DEFAULT_SUPABASE_URL).trim();
  const anonKey = (options.supabaseAnonKey || DEFAULT_SUPABASE_ANON_KEY).trim();
  let lastError: unknown;

  for (let attempt = 1; attempt <= 5; attempt += 1) {
    try {
      const response = await fetch(`${supabaseUrl}/auth/v1/token?grant_type=password`, {
        method: 'POST',
        headers: {
          apikey: anonKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          email: options.email,
          password: options.password,
        }),
        signal: AbortSignal.timeout(20_000),
      });

      const payload = (await response.json().catch(() => ({}))) as Record<string, unknown>;
      if (!response.ok) {
        // Invalid credentials should fail immediately; transient provider errors may retry.
        if (response.status < 500) {
          throw new Error(`Supabase session bootstrap failed: ${JSON.stringify(payload)}`);
        }
        throw new Error(
          `Supabase session bootstrap failed with ${response.status}: ${JSON.stringify(payload)}`,
        );
      }

      return payload;
    } catch (error) {
      lastError = error;
      if (attempt >= 5 || !isRetriableBootstrapError(error)) break;
      await new Promise((resolve) => setTimeout(resolve, attempt * 1_250));
    }
  }

  throw formatBootstrapError(lastError);
}

export async function seedBrowserSession(
  page: Page,
  options: {
    baseUrl: string;
    session: SupabaseSession;
    storageKey?: string;
  },
): Promise<void> {
  const baseUrl = cleanBaseUrl(options.baseUrl);
  const storageKey =
    options.storageKey || resolveSupabaseStorageKey(process.env.SUPABASE_URL);

  await page.context().clearCookies();
  await page.goto(`${baseUrl}/?seed=${Date.now()}`, {
    waitUntil: 'domcontentloaded',
  });
  await page.evaluate(() => {
    localStorage.clear();
    sessionStorage.clear();
  });
  await page.addInitScript(
    ({ session, storageKey }) => {
      localStorage.setItem(storageKey, JSON.stringify(session));
    },
    { session: options.session, storageKey },
  );
  await gotoApp(page, `${baseUrl}/`, 120_000);
}

export async function openHashRoute(
  page: Page,
  pathname: string,
  waitMs = 2500,
): Promise<void> {
  const currentUrl = new URL(page.url());
  currentUrl.hash = `#${pathname}`;
  await gotoApp(page, currentUrl.toString(), 120_000);
  await page.waitForTimeout(waitMs);
}

export function currentAppPath(page: Page): string {
  const url = page.url();
  try {
    const parsed = new URL(url);
    if (parsed.hash.startsWith('#/')) {
      return parsed.hash.slice(1);
    }
    return parsed.pathname || '/';
  } catch {
    return url;
  }
}
