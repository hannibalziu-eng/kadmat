import { jest, describe, it, expect } from '@jest/globals';

jest.unstable_mockModule('../src/services/jobService.js', () => ({
  jobService: {},
}));

jest.unstable_mockModule('../src/services/jobSearchService.js', () => ({
  startJobSearch: jest.fn(),
  onJobAccepted: jest.fn(),
  cancelJobSearch: jest.fn(),
}));

const { acceptJob } = await import('../src/controllers/jobController.js');

describe('jobController legacy accept endpoint', () => {
  it('returns 409 and bidding-only contract details', async () => {
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
    expect(res.json).toHaveBeenCalledTimes(1);

    const payload = res.json.mock.calls[0][0];
    expect(payload.success).toBe(false);
    expect(payload.error.code).toBe('INVALID_STATUS_TRANSITION');
    expect(payload.error.details.flow).toBe('bidding_only');
    expect(payload.error.details.action).toBe('submit_offer');
  });
});

