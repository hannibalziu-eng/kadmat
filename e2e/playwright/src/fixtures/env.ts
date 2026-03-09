export type KadmatEnv = {
  baseUrl: string;
  apiBase: string;
  customerEmail: string;
  customerPass: string;
  technicianEmail: string;
  technicianPass: string;
  customerToken?: string;
  technicianToken?: string;
  technicianPublicId?: string;
  strictRealData: boolean;
  seedOnStart: boolean;
  cleanupOnEnd: boolean;
  supabaseUrl?: string;
  supabaseAnonKey?: string;
  supabaseServiceRoleKey?: string;
};

function asBool(value: string | undefined, fallback = false): boolean {
  if (value == null || value.trim() === '') return fallback;
  return ['1', 'true', 'yes', 'on'].includes(value.trim().toLowerCase());
}

function clean(value: string | undefined): string | undefined {
  const normalized = value?.trim();
  return normalized ? normalized : undefined;
}

export function readEnv(): KadmatEnv {
  return {
    baseUrl: process.env.BASE_URL?.trim() || 'http://127.0.0.1:7357',
    apiBase: process.env.API_BASE?.trim() || 'http://127.0.0.1:3000/api',
    customerEmail: process.env.CUSTOMER_EMAIL?.trim() || '',
    customerPass: process.env.CUSTOMER_PASS?.trim() || '',
    technicianEmail: process.env.TECHNICIAN_EMAIL?.trim() || '',
    technicianPass: process.env.TECHNICIAN_PASS?.trim() || '',
    customerToken: clean(process.env.CUSTOMER_TOKEN),
    technicianToken: clean(process.env.TECHNICIAN_TOKEN),
    technicianPublicId: clean(process.env.TECHNICIAN_PUBLIC_ID),
    strictRealData: asBool(process.env.STRICT_REAL_DATA, false),
    seedOnStart: asBool(process.env.E2E_SEED_ON_START, false),
    cleanupOnEnd: asBool(process.env.E2E_CLEANUP_ON_END, false),
    supabaseUrl: clean(process.env.SUPABASE_URL),
    supabaseAnonKey: clean(process.env.SUPABASE_ANON_KEY),
    supabaseServiceRoleKey: clean(process.env.SUPABASE_SERVICE_ROLE_KEY),
  };
}

export const env = readEnv();

export function hasCustomerCredentials(): boolean {
  return !!(env.customerToken || (env.customerEmail && env.customerPass));
}

export function hasTechnicianCredentials(): boolean {
  return !!(env.technicianToken || (env.technicianEmail && env.technicianPass));
}

export function requiresSeedingConfig(): boolean {
  return !!(env.supabaseUrl && env.supabaseServiceRoleKey);
}
