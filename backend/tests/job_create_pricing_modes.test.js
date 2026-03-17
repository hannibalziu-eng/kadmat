import { jest, describe, it, expect, beforeEach } from '@jest/globals';

let jobsInsertPayloads;
let jobCatalogItemsInsertPayloads;
let jobImagesInsertPayloads;

const activeService = {
  id: 'service-1',
  is_active: true,
  is_catalog_enabled: true,
  pricing_mode_default: 'catalog_fixed',
};

const catalogRows = [
  {
    id: 'item-1',
    service_id: 'service-1',
    is_active: true,
    name: 'Diagnostic',
    name_ar: 'فحص',
    price: 40,
    currency_code: 'LYD',
  },
  {
    id: 'item-2',
    service_id: 'service-1',
    is_active: true,
    name: 'Cleaning',
    name_ar: 'تنظيف',
    price: 25,
    currency_code: 'LYD',
  },
];

const supabaseAdminMock = {
  from: jest.fn((table) => {
    if (table === 'jobs') {
      let insertPayload = null;
      return {
        insert: jest.fn((payload) => {
          insertPayload = payload;
          jobsInsertPayloads.push(payload);
          return {
            select: jest.fn(() => ({
              single: jest.fn(async () => ({
                data: { id: `job-${jobsInsertPayloads.length}`, ...insertPayload },
                error: null,
              })),
            })),
          };
        }),
      };
    }

    if (table === 'services') {
      return {
        select: jest.fn(() => ({
          eq: jest.fn(() => ({
            maybeSingle: jest.fn(async () => ({
              data: activeService,
              error: null,
            })),
          })),
        })),
      };
    }

    if (table === 'service_catalog_items') {
      return {
        select: jest.fn(() => {
          const state = { serviceId: null, isActive: null, ids: [] };
          const chain = {
            eq: jest.fn((field, value) => {
              if (field === 'service_id') state.serviceId = value;
              if (field === 'is_active') state.isActive = value;
              return chain;
            }),
            in: jest.fn(async (_field, ids) => ({
              data: catalogRows.filter(
                (row) =>
                  row.service_id === state.serviceId &&
                  row.is_active === state.isActive &&
                  ids.includes(row.id),
              ),
              error: null,
            })),
          };
          return chain;
        }),
      };
    }

    if (table === 'job_catalog_items') {
      return {
        insert: jest.fn(async (payload) => {
          jobCatalogItemsInsertPayloads.push(payload);
          return { data: payload, error: null };
        }),
      };
    }

    if (table === 'job_images') {
      return {
        insert: jest.fn(async (payload) => {
          jobImagesInsertPayloads.push(payload);
          return { data: payload, error: null };
        }),
      };
    }

    return {
      insert: jest.fn(async () => ({ data: null, error: null })),
      select: jest.fn().mockReturnThis(),
      eq: jest.fn().mockReturnThis(),
      in: jest.fn().mockReturnThis(),
      maybeSingle: jest.fn(async () => ({ data: null, error: null })),
      single: jest.fn(async () => ({ data: null, error: null })),
    };
  }),
};

jest.unstable_mockModule('../src/config/supabase.js', () => ({
  supabaseAdmin: supabaseAdminMock,
}));

jest.unstable_mockModule('../src/services/fcmService.js', () => ({
  notifyPriceRequest: jest.fn(async () => undefined),
  notifyJobCompleted: jest.fn(async () => undefined),
  sendPushNotification: jest.fn(async () => undefined),
}));

const { jobService } = await import('../src/services/jobService.js');

describe('JobService.create pricing modes', () => {
  beforeEach(() => {
    jobsInsertPayloads = [];
    jobCatalogItemsInsertPayloads = [];
    jobImagesInsertPayloads = [];
    supabaseAdminMock.from.mockClear();

    jobService._ensureCustomerCanCreateJob = jest.fn(async () => undefined);
    jobService._cancelOpenSearchJobsForCustomer = jest.fn(async () => undefined);
  });

  it('defaults to technician_quote and keeps the legacy create path', async () => {
    const job = await jobService.create('customer-1', {
      service_id: 'service-1',
      lat: 32.88,
      lng: 13.19,
      address_text: 'Tripoli',
      description: 'Need inspection',
      initial_price: 90,
    });

    expect(job.id).toBe('job-1');
    expect(jobsInsertPayloads).toHaveLength(1);
    expect(jobsInsertPayloads[0]).toMatchObject({
      customer_id: 'customer-1',
      service_id: 'service-1',
      pricing_mode: 'technician_quote',
      quote_required: true,
      catalog_item_count: 0,
      catalog_subtotal: null,
    });
    expect(jobCatalogItemsInsertPayloads).toHaveLength(0);
  });

  it('creates catalog_fixed jobs and persists job_catalog_items', async () => {
    const job = await jobService.create('customer-1', {
      service_id: 'service-1',
      lat: 32.88,
      lng: 13.19,
      address_text: 'Tripoli',
      description: 'Need fixed-price package',
      initial_price: 0,
      pricing_mode: 'catalog_fixed',
      catalog_items: [
        { service_catalog_item_id: 'item-1', quantity: 2 },
        { service_catalog_item_id: 'item-2', quantity: 1 },
      ],
    });

    expect(jobsInsertPayloads).toHaveLength(1);
    expect(jobsInsertPayloads[0]).toMatchObject({
      customer_id: 'customer-1',
      service_id: 'service-1',
      pricing_mode: 'catalog_fixed',
      quote_required: false,
      catalog_item_count: 3,
      catalog_subtotal: 105,
      initial_price: 105,
    });
    expect(jobCatalogItemsInsertPayloads).toHaveLength(1);
    expect(jobCatalogItemsInsertPayloads[0]).toHaveLength(2);
    expect(job.job_catalog_items).toHaveLength(2);
    expect(job.job_catalog_items[0]).toMatchObject({
      service_catalog_item_id: 'item-1',
      quantity: 2,
      line_total: 80,
    });
    expect(job.job_catalog_items[1]).toMatchObject({
      service_catalog_item_id: 'item-2',
      quantity: 1,
      line_total: 25,
    });
  });
});
