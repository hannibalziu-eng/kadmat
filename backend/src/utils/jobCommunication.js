import { JOB_STATES } from './jobStateMachine.js';

export const COMMUNICATION_ELIGIBLE_STATUSES = new Set([
  JOB_STATES.ACCEPTED,
  JOB_STATES.PRICE_PENDING,
  JOB_STATES.ON_THE_WAY,
  JOB_STATES.ARRIVED,
  JOB_STATES.IN_PROGRESS,
  JOB_STATES.PENDING_CONFIRM,
  JOB_STATES.COMPLETED,
  JOB_STATES.RATED,
]);

export function canUseJobCommunication(job) {
  if (!job) return false;

  const acceptedBidId =
    typeof job.accepted_bid_id === 'string' ? job.accepted_bid_id.trim() : '';
  const status = typeof job.status === 'string' ? job.status.trim() : '';

  if (
    status === JOB_STATES.PENDING ||
    status === JOB_STATES.SEARCHING ||
    status === JOB_STATES.NO_TECHNICIAN ||
    status === JOB_STATES.CANCELLED
  ) {
    return false;
  }

  if (COMMUNICATION_ELIGIBLE_STATUSES.has(status)) {
    return true;
  }

  return acceptedBidId.length > 0;
}

export function communicationDeniedDetails(job) {
  return {
    currentStatus: job?.status ?? null,
    acceptedBidId: job?.accepted_bid_id ?? null,
  };
}
