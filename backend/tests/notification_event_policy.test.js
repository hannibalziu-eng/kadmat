import { describe, it, expect } from '@jest/globals';
import {
  resolveNotificationEventPolicy,
  resolveNotificationDedupeKey,
} from '../src/constants/notificationEventPolicy.js';

describe('notification event policy', () => {
  it('resolves per-event matrix for technician_arrived', () => {
    const policy = resolveNotificationEventPolicy('technician_arrived');

    expect(policy).toEqual({
      ttlSeconds: 300,
      pushChannelId: 'critical_alerts',
      collapseScope: 'order_status',
      autoDedupe: true,
    });
  });

  it('applies overrides on top of registry', () => {
    const policy = resolveNotificationEventPolicy('technician_arrived', {
      ttlSeconds: 120,
      pushChannelId: 'important_updates',
    });

    expect(policy.ttlSeconds).toBe(120);
    expect(policy.pushChannelId).toBe('important_updates');
    expect(policy.collapseScope).toBe('order_status');
    expect(policy.autoDedupe).toBe(true);
  });

  it.each([
    'job_cancelled_by_customer',
    'job_cancelled_by_technician',
  ])('resolves cancellation policy matrix for %s', (eventType) => {
    const policy = resolveNotificationEventPolicy(eventType);

    expect(policy).toEqual({
      ttlSeconds: 1200,
      pushChannelId: 'critical_alerts',
      collapseScope: 'order_status',
      autoDedupe: true,
    });
  });

  it('generates deterministic dedupe keys when explicit key is absent', () => {
    const key = resolveNotificationDedupeKey({
      eventType: 'price_request',
      orderId: 'job-88',
      userId: 'user-22',
      autoDedupe: true,
    });

    expect(key).toBe('price_request:job-88:user-22');
  });

  it('keeps explicit dedupe key as-is', () => {
    const key = resolveNotificationDedupeKey({
      explicitDedupeKey: 'manual-key',
      eventType: 'price_request',
      orderId: 'job-88',
      userId: 'user-22',
      autoDedupe: true,
    });

    expect(key).toBe('manual-key');
  });

  it('returns null when auto dedupe disabled and no explicit key', () => {
    const key = resolveNotificationDedupeKey({
      eventType: 'warning',
      autoDedupe: false,
    });

    expect(key).toBeNull();
  });
});
