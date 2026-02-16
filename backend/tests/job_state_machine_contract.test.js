import { describe, expect, it } from '@jest/globals';
import { JOB_STATES, VALID_TRANSITIONS, validateTransition } from '../src/utils/jobStateMachine.js';

describe('Job state machine contract', () => {
  it('keeps only canonical statuses (no expired state)', () => {
    const statuses = Object.values(JOB_STATES);
    expect(statuses).not.toContain('expired');
    expect(statuses).toContain('no_technician_found');
    expect(statuses).toContain('pending_confirm');
    expect(statuses).toContain('rated');
    expect(statuses).toContain('on_the_way');
    expect(statuses).toContain('arrived');
  });

  it('allows cancel transition from no_technician_found', () => {
    expect(VALID_TRANSITIONS[JOB_STATES.NO_TECHNICIAN]).toContain(
      JOB_STATES.CANCELLED,
    );
  });

  it('rejects non-canonical transition target', () => {
    expect(() => validateTransition(JOB_STATES.NO_TECHNICIAN, 'expired')).toThrow(
      /Cannot transition job/,
    );
  });
});
