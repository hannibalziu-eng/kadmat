import { describe, it, expect } from '@jest/globals';
import {
  buildAndValidateNotificationEvent,
  notificationEventContractBounds,
} from '../src/constants/notificationEventContract.js';

describe('notification event contract', () => {
  it('builds a valid contract with defaults from payload', () => {
    const result = buildAndValidateNotificationEvent({
      eventType: 'technician_arrived',
      data: {
        job_id: 'job-123',
        deep_link: '/orders/job-123/tracking',
      },
      dedupeKey: 'event-abc-1',
      priority: 4,
    });

    expect(result).toEqual({
      event_type: 'technician_arrived',
      order_id: 'job-123',
      deep_link: '/orders/job-123/tracking',
      dedupe_key: 'event-abc-1',
      collapse_key: 'order_job-123_status',
      channel_id: 'critical_alerts',
      priority: 4,
      ttl_seconds: notificationEventContractBounds.DEFAULT_TTL_SECONDS_HIGH,
    });
  });

  it('assigns low priority defaults when priority is not urgent', () => {
    const result = buildAndValidateNotificationEvent({
      eventType: 'warning',
      data: {},
      priority: 2,
    });

    expect(result.channel_id).toBe('standard_notifications');
    expect(result.ttl_seconds).toBe(notificationEventContractBounds.DEFAULT_TTL_SECONDS_LOW);
  });

  it('throws when ttl is outside supported bounds', () => {
    expect(() =>
      buildAndValidateNotificationEvent({
        eventType: 'warning',
        priority: 3,
        ttlSeconds: 5,
      })
    ).toThrow('Notification event contract validation failed');

    try {
      buildAndValidateNotificationEvent({
        eventType: 'warning',
        priority: 3,
        ttlSeconds: 5,
      });
    } catch (error) {
      expect(error.code).toBe('NOTIFICATION_EVENT_CONTRACT_INVALID');
      expect(Array.isArray(error.details)).toBe(true);
      expect(error.details.some((item) => item.path === 'ttl_seconds')).toBe(true);
    }
  });
});
