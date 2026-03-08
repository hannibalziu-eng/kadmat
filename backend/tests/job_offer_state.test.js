import { beforeEach, describe, expect, it, jest } from '@jest/globals';

const selectMock = jest.fn();
const eqMock = jest.fn();

jest.unstable_mockModule('../src/config/supabase.js', () => ({
  supabaseAdmin: {
    from: jest.fn(() => ({
      select: selectMock,
    })),
  },
}));

const { hasActivePendingOffers } = await import(
  '../src/utils/jobOfferState.js'
);

describe('jobOfferState', () => {
  beforeEach(() => {
    eqMock.mockReset();
    selectMock.mockReset();
  });

  it('returns true when active pending offers exist', async () => {
    eqMock
      .mockReturnValueOnce({ eq: eqMock })
      .mockReturnValueOnce({ eq: eqMock })
      .mockResolvedValueOnce({ count: 2, error: null });

    selectMock.mockReturnValue({ eq: eqMock });

    await expect(hasActivePendingOffers('job-1')).resolves.toBe(true);
  });

  it('returns false when no active pending offers exist', async () => {
    eqMock
      .mockReturnValueOnce({ eq: eqMock })
      .mockReturnValueOnce({ eq: eqMock })
      .mockResolvedValueOnce({ count: 0, error: null });

    selectMock.mockReturnValue({ eq: eqMock });

    await expect(hasActivePendingOffers('job-1')).resolves.toBe(false);
  });

  it('throws when the offers query fails', async () => {
    eqMock
      .mockReturnValueOnce({ eq: eqMock })
      .mockReturnValueOnce({ eq: eqMock })
      .mockResolvedValueOnce({
        count: 0,
        error: { message: 'boom' },
      });

    selectMock.mockReturnValue({ eq: eqMock });

    await expect(hasActivePendingOffers('job-1')).rejects.toThrow(
      'Failed to check active offers: boom',
    );
  });
});
