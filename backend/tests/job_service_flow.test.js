import { jest, describe, it, expect, beforeEach } from '@jest/globals';

let mockJob;
let notifications;
let offers;
let onTheWayConstraintFailuresRemaining;

const fcmMocks = {
  notifyPriceRequest: jest.fn(async () => undefined),
  notifyJobCompleted: jest.fn(async () => undefined),
  sendPushNotification: jest.fn(async () => undefined),
};

function applyJobUpdate(payload, { allowedStatuses, requireNullTechnician }) {
  if (allowedStatuses && !allowedStatuses.includes(mockJob.status)) {
    return null;
  }

  if (requireNullTechnician && mockJob.technician_id != null) {
    return null;
  }

  mockJob = { ...mockJob, ...payload };
  return mockJob;
}

function buildJobsQuery() {
  let updatePayload = null;
  let allowedStatuses = null;
  let requireNullTechnician = false;
  const equalsFilters = {};
  const notEqualsFilters = {};

  const getFilteredRows = () => {
    const rows = [mockJob].filter((row) => {
      if (
        Object.entries(equalsFilters).some(
          ([key, value]) => row[key] !== value,
        )
      ) {
        return false;
      }
      if (
        Object.entries(notEqualsFilters).some(
          ([key, value]) => row[key] === value,
        )
      ) {
        return false;
      }
      if (allowedStatuses && !allowedStatuses.includes(row.status)) {
        return false;
      }
      return true;
    });
    return rows;
  };

  const query = {
    select: jest.fn(() => query),
    eq: jest.fn((column, value) => {
      equalsFilters[column] = value;
      return query;
    }),
    neq: jest.fn((column, value) => {
      notEqualsFilters[column] = value;
      return query;
    }),
    in: jest.fn((column, values) => {
      if (column === 'status') {
        allowedStatuses = values;
      }
      return query;
    }),
    is: jest.fn((column, value) => {
      if (column === 'technician_id' && value === null) {
        requireNullTechnician = true;
      }
      return query;
    }),
    limit: jest.fn(async (count) => ({
      data: getFilteredRows().slice(0, count),
      error: null,
    })),
    update: jest.fn((payload) => {
      updatePayload = payload;
      return query;
    }),
    insert: jest.fn(async () => ({ data: null, error: null })),
    maybeSingle: jest.fn(async () => {
      if (updatePayload == null) {
        return { data: mockJob, error: null };
      }
      if (
        updatePayload.status === 'on_the_way' &&
        onTheWayConstraintFailuresRemaining > 0
      ) {
        onTheWayConstraintFailuresRemaining -= 1;
        return {
          data: null,
          error: {
            message:
              'new row for relation "jobs" violates check constraint "jobs_status_check"',
            code: '23514',
            details: null,
            hint: null,
          },
        };
      }
      return {
        data: applyJobUpdate(updatePayload, {
          allowedStatuses,
          requireNullTechnician,
        }),
        error: null,
      };
    }),
    single: jest.fn(async () => {
      if (updatePayload == null) {
        return { data: mockJob, error: null };
      }
      return {
        data: applyJobUpdate(updatePayload, {
          allowedStatuses,
          requireNullTechnician,
        }),
        error: null,
      };
    }),
  };

  return query;
}

function buildNotificationsQuery() {
  return {
    insert: jest.fn(async (payload) => {
      notifications.push(payload);
      return { data: payload, error: null };
    }),
  };
}

function buildJobOffersQuery() {
  let insertPayload = null;
  let updatePayload = null;
  let offerIdFilter = null;
  let jobIdFilter = null;
  let notOfferIdFilter = null;

  const query = {
    select: jest.fn(() => query),
    insert: jest.fn((payload) => {
      insertPayload = payload;
      return query;
    }),
    update: jest.fn((payload) => {
      updatePayload = payload;
      return query;
    }),
    eq: jest.fn((column, value) => {
      if (column === 'id') {
        offerIdFilter = value;
      }
      if (column === 'job_id') {
        jobIdFilter = value;
      }

      if (updatePayload && column === 'id') {
        const index = offers.findIndex((o) => o.id === value);
        if (index >= 0) {
          offers[index] = { ...offers[index], ...updatePayload };
        }
      }

      if (updatePayload && column === 'job_id') {
        offers = offers.map((o) => {
          if (o.job_id !== value) return o;
          if (notOfferIdFilter != null && o.id === notOfferIdFilter) return o;
          return { ...o, ...updatePayload };
        });
      }

      return query;
    }),
    neq: jest.fn((column, value) => {
      if (column === 'id') {
        notOfferIdFilter = value;
      }
      return query;
    }),
    single: jest.fn(async () => {
      if (insertPayload) {
        const createdOffer = {
          id: `offer-${offers.length + 1}`,
          ...insertPayload,
        };
        offers.push(createdOffer);
        return { data: createdOffer, error: null };
      }

      if (offerIdFilter) {
        const offer = offers.find((o) => {
          if (o.id !== offerIdFilter) return false;
          if (jobIdFilter && o.job_id !== jobIdFilter) return false;
          return true;
        }) || null;
        return { data: offer, error: null };
      }

      return { data: null, error: null };
    }),
  };

  return query;
}

const supabaseAdminMock = {
  from: jest.fn((table) => {
    if (table === 'jobs') {
      return buildJobsQuery();
    }

    if (table === 'notifications') {
      return buildNotificationsQuery();
    }

    if (table === 'job_offers') {
      return buildJobOffersQuery();
    }

    return {
      insert: jest.fn(async () => ({ data: null, error: null })),
      select: jest.fn().mockReturnThis(),
      eq: jest.fn().mockReturnThis(),
      single: jest.fn(async () => ({ data: null, error: null })),
    };
  }),
  rpc: jest.fn(async () => ({ data: true, error: null })),
};

jest.unstable_mockModule('../src/config/supabase.js', () => ({
  supabaseAdmin: supabaseAdminMock,
}));

jest.unstable_mockModule('../src/services/fcmService.js', () => fcmMocks);

const { jobService } = await import('../src/services/jobService.js');

describe('JobService critical flow', () => {
  beforeEach(() => {
    mockJob = {
      id: 'job-1',
      customer_id: 'customer-1',
      technician_id: null,
      status: 'pending',
      metadata: {},
      final_price: null,
      technician_price: null,
    };
    notifications = [];
    offers = [];
    onTheWayConstraintFailuresRemaining = 0;
    supabaseAdminMock.from.mockClear();
    supabaseAdminMock.rpc.mockClear();
    fcmMocks.notifyPriceRequest.mockClear();
    fcmMocks.notifyJobCompleted.mockClear();
    fcmMocks.sendPushNotification.mockClear();
  });

  it('runs full happy-path transition flow to completed', async () => {
    const accepted = await jobService.accept('job-1', 'tech-1');
    expect(accepted.status).toBe('accepted');
    expect(accepted.technician_id).toBe('tech-1');

    const pricePending = await jobService.setPrice(
      'job-1',
      'tech-1',
      120,
      'initial estimate',
      'cash',
    );
    expect(pricePending.status).toBe('price_pending');
    expect(pricePending.technician_price).toBe(120);

    const onTheWay = await jobService.confirmPrice('job-1', 'customer-1');
    expect(onTheWay.status).toBe('on_the_way');
    expect(onTheWay.final_price).toBe(120);

    const arrived = await jobService.updateTechnicianProgress(
      'job-1',
      'tech-1',
      'arrived',
    );
    expect(arrived.status).toBe('arrived');

    const inProgress = await jobService.updateTechnicianProgress(
      'job-1',
      'tech-1',
      'start_work',
    );
    expect(inProgress.status).toBe('in_progress');

    const pendingConfirm = await jobService.requestCompletion('job-1', 'tech-1', {
      finalPrice: 130,
      notes: 'work done',
      afterPhotos: ['https://img/after-1.jpg'],
    });
    expect(pendingConfirm.status).toBe('pending_confirm');
    expect(pendingConfirm.final_price).toBe(130);

    const completed = await jobService.confirmJobCompletion(
      'job-1',
      'customer-1',
      'card',
    );
    expect(completed.status).toBe('completed');
    expect(completed.metadata.payment_method).toBe('card');
    expect(completed.metadata.payment_status).toBe('paid');

    expect(fcmMocks.notifyPriceRequest).toHaveBeenCalledTimes(1);
    expect(fcmMocks.sendPushNotification).toHaveBeenCalledTimes(3);
    expect(fcmMocks.notifyJobCompleted).toHaveBeenCalledTimes(1);
    expect(supabaseAdminMock.rpc).toHaveBeenCalledWith('process_job_payment', {
      job_id: 'job-1',
      tech_id: 'tech-1',
      amount: 130,
    });
    expect(notifications.length).toBeGreaterThanOrEqual(4);
  });

  it('rejects accepting job from invalid state', async () => {
    mockJob = { ...mockJob, status: 'completed' };

    await expect(jobService.accept('job-1', 'tech-1')).rejects.toMatchObject({
      code: 'INVALID_STATUS_TRANSITION',
    });
  });

  it('rejects accept when job already taken by another technician', async () => {
    mockJob = {
      ...mockJob,
      status: 'accepted',
      technician_id: 'other-tech',
    };

    await expect(jobService.accept('job-1', 'tech-1')).rejects.toMatchObject({
      code: 'JOB_ALREADY_ACCEPTED',
    });
  });

  it('supports submit-offer then accept-offer flow', async () => {
    const offer = await jobService.submitOffer('job-1', 'tech-2', 90);
    expect(offer.id).toBe('offer-1');
    expect(offer.job_id).toBe('job-1');
    expect(offer.technician_id).toBe('tech-2');
    expect(offer.price).toBe(90);
    expect(offer.status).toBe('pending');

    const updatedJob = await jobService.acceptOffer(
      'job-1',
      'customer-1',
      offer.id,
    );
    expect(updatedJob.status).toBe('on_the_way');
    expect(updatedJob.technician_id).toBe('tech-2');
    expect(updatedJob.technician_price).toBe(90);
    expect(updatedJob.final_price).toBe(90);

    expect(notifications.some((n) => n.type == 'new_offer')).toBe(true);
    expect(notifications.some((n) => n.type == 'offer_accepted')).toBe(true);
  });

  it('accept-offer falls back to in_progress when on_the_way status is unavailable', async () => {
    onTheWayConstraintFailuresRemaining = 1;

    const offer = await jobService.submitOffer('job-1', 'tech-2', 90);
    const updatedJob = await jobService.acceptOffer(
      'job-1',
      'customer-1',
      offer.id,
    );

    expect(updatedJob.status).toBe('in_progress');
    expect(updatedJob.technician_id).toBe('tech-2');
    expect(updatedJob.technician_price).toBe(90);
    expect(updatedJob.final_price).toBe(90);
  });

  it('rejects accept-offer when customer does not own the job', async () => {
    offers.push({
      id: 'offer-1',
      job_id: 'job-1',
      technician_id: 'tech-2',
      price: 90,
      status: 'pending',
    });

    await expect(
      jobService.acceptOffer('job-1', 'customer-2', 'offer-1'),
    ).rejects.toThrow('Unauthorized');
  });

  it('allows cancel when job is no_technician_found', async () => {
    mockJob = {
      ...mockJob,
      status: 'no_technician_found',
      metadata: { existing: true },
    };

    const cancelled = await jobService.cancel(
      'job-1',
      'customer-1',
      'customer_cancelled',
    );

    expect(cancelled.status).toBe('cancelled');
    expect(cancelled.metadata.cancellation_reason).toBe('customer_cancelled');
    expect(cancelled.metadata.cancelled_by).toBe('customer-1');
    expect(cancelled.metadata.existing).toBe(true);
  });
});
