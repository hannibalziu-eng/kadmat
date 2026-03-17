import { jest, describe, it, expect, beforeEach } from '@jest/globals';

let currentJob = null;

const jobServiceMock = {
  accept: jest.fn(),
};

const onJobAcceptedMock = jest.fn();

jest.unstable_mockModule('../src/config/supabase.js', () => {
  const chain = {
    select: jest.fn().mockReturnThis(),
    eq: jest.fn().mockReturnThis(),
    maybeSingle: jest.fn(async () => ({
      data: currentJob,
      error: null,
    })),
  };

  return {
    supabase: {
      from: jest.fn(() => chain),
    },
  };
});

jest.unstable_mockModule('../src/services/jobService.js', () => ({
  jobService: jobServiceMock,
}));

jest.unstable_mockModule('../src/services/jobSearchService.js', () => ({
  startJobSearch: jest.fn(),
  onJobAccepted: onJobAcceptedMock,
  cancelJobSearch: jest.fn(),
}));

const { acceptJob } = await import('../src/controllers/jobController.js');

describe('jobController accept endpoint gating', () => {
  beforeEach(() => {
    currentJob = null;
    jobServiceMock.accept.mockReset();
    onJobAcceptedMock.mockReset();
  });

  it('returns 409 and bidding-only contract details for technician_quote jobs', async () => {
    currentJob = {
      id: 'job-1',
      pricing_mode: 'technician_quote',
    };

    const req = {
      params: { id: 'job-1' },
      user: { id: 'tech-1', user_type: 'technician' },
    };

    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };

    await acceptJob(req, res);

    expect(res.status).toHaveBeenCalledWith(409);
    expect(jobServiceMock.accept).not.toHaveBeenCalled();

    const payload = res.json.mock.calls[0][0];
    expect(payload.success).toBe(false);
    expect(payload.error.code).toBe('INVALID_STATUS_TRANSITION');
    expect(payload.error.details.flow).toBe('bidding_only');
    expect(payload.error.details.action).toBe('submit_offer');
    expect(payload.error.details.pricingMode).toBe('technician_quote');
  });

  it('allows direct accept for catalog_fixed jobs', async () => {
    currentJob = {
      id: 'job-1',
      pricing_mode: 'catalog_fixed',
    };
    jobServiceMock.accept.mockResolvedValue({
      id: 'job-1',
      pricing_mode: 'catalog_fixed',
      status: 'accepted',
      technician_id: 'tech-1',
    });

    const req = {
      params: { id: 'job-1' },
      user: { id: 'tech-1', user_type: 'technician' },
    };

    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };

    await acceptJob(req, res);

    expect(jobServiceMock.accept).toHaveBeenCalledWith('job-1', 'tech-1');
    expect(onJobAcceptedMock).toHaveBeenCalledWith('job-1');
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: expect.objectContaining({
          id: 'job-1',
          status: 'accepted',
        }),
      }),
    );
  });
});
