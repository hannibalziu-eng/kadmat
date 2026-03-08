class NotificationAudienceRole {
  static const customer = 'customer';
  static const technician = 'technician';
  static const admin = 'admin';
  static const all = 'all';

  static const values = <String>{customer, technician, admin, all};
}

class NotificationCategory {
  static const job = 'job';
  static const offer = 'offer';
  static const payment = 'payment';
  static const message = 'message';
  static const system = 'system';

  static const values = <String>{job, offer, payment, message, system};
}

class NotificationChannel {
  static const inbox = 'inbox';
  static const push = 'push';
  static const inApp = 'in_app';

  static const values = <String>{inbox, push, inApp};
}

class NotificationContractEntry {
  final String type;
  final String audienceRole;
  final String category;
  final List<String> channels;
  final int priority;
  final String? entityType;

  const NotificationContractEntry({
    required this.type,
    required this.audienceRole,
    required this.category,
    required this.channels,
    required this.priority,
    this.entityType,
  });
}

const Map<String, NotificationContractEntry> notificationContractRegistry = {
  'new_job_offer': NotificationContractEntry(
    type: 'new_job_offer',
    audienceRole: NotificationAudienceRole.technician,
    category: NotificationCategory.job,
    channels: [
      NotificationChannel.inbox,
      NotificationChannel.push,
      NotificationChannel.inApp,
    ],
    priority: 4,
    entityType: 'job',
  ),
  'new_offer': NotificationContractEntry(
    type: 'new_offer',
    audienceRole: NotificationAudienceRole.customer,
    category: NotificationCategory.offer,
    channels: [
      NotificationChannel.inbox,
      NotificationChannel.push,
      NotificationChannel.inApp,
    ],
    priority: 4,
    entityType: 'job',
  ),
  'offer_accepted': NotificationContractEntry(
    type: 'offer_accepted',
    audienceRole: NotificationAudienceRole.technician,
    category: NotificationCategory.message,
    channels: [
      NotificationChannel.inbox,
      NotificationChannel.push,
      NotificationChannel.inApp,
    ],
    priority: 5,
    entityType: 'job',
  ),
  'price_request': NotificationContractEntry(
    type: 'price_request',
    audienceRole: NotificationAudienceRole.customer,
    category: NotificationCategory.offer,
    channels: [
      NotificationChannel.inbox,
      NotificationChannel.push,
      NotificationChannel.inApp,
    ],
    priority: 4,
    entityType: 'job',
  ),
  'price_confirmed': NotificationContractEntry(
    type: 'price_confirmed',
    audienceRole: NotificationAudienceRole.technician,
    category: NotificationCategory.message,
    channels: [
      NotificationChannel.inbox,
      NotificationChannel.push,
      NotificationChannel.inApp,
    ],
    priority: 4,
    entityType: 'job',
  ),
  'technician_arrived': NotificationContractEntry(
    type: 'technician_arrived',
    audienceRole: NotificationAudienceRole.customer,
    category: NotificationCategory.message,
    channels: [
      NotificationChannel.inbox,
      NotificationChannel.push,
      NotificationChannel.inApp,
    ],
    priority: 4,
    entityType: 'job',
  ),
  'work_started': NotificationContractEntry(
    type: 'work_started',
    audienceRole: NotificationAudienceRole.customer,
    category: NotificationCategory.message,
    channels: [NotificationChannel.inbox, NotificationChannel.inApp],
    priority: 3,
    entityType: 'job',
  ),
  'completion_request': NotificationContractEntry(
    type: 'completion_request',
    audienceRole: NotificationAudienceRole.customer,
    category: NotificationCategory.message,
    channels: [
      NotificationChannel.inbox,
      NotificationChannel.push,
      NotificationChannel.inApp,
    ],
    priority: 4,
    entityType: 'job',
  ),
  'job_cancelled_by_customer': NotificationContractEntry(
    type: 'job_cancelled_by_customer',
    audienceRole: NotificationAudienceRole.technician,
    category: NotificationCategory.message,
    channels: [
      NotificationChannel.inbox,
      NotificationChannel.push,
      NotificationChannel.inApp,
    ],
    priority: 4,
    entityType: 'job',
  ),
  'job_cancelled_by_technician': NotificationContractEntry(
    type: 'job_cancelled_by_technician',
    audienceRole: NotificationAudienceRole.customer,
    category: NotificationCategory.message,
    channels: [
      NotificationChannel.inbox,
      NotificationChannel.push,
      NotificationChannel.inApp,
    ],
    priority: 4,
    entityType: 'job',
  ),
  'job_completed': NotificationContractEntry(
    type: 'job_completed',
    audienceRole: NotificationAudienceRole.technician,
    category: NotificationCategory.payment,
    channels: [NotificationChannel.inbox, NotificationChannel.inApp],
    priority: 4,
    entityType: 'job',
  ),
  'no_technician': NotificationContractEntry(
    type: 'no_technician',
    audienceRole: NotificationAudienceRole.customer,
    category: NotificationCategory.job,
    channels: [NotificationChannel.inbox, NotificationChannel.inApp],
    priority: 3,
    entityType: 'job',
  ),
  'technician_timeout': NotificationContractEntry(
    type: 'technician_timeout',
    audienceRole: NotificationAudienceRole.customer,
    category: NotificationCategory.message,
    channels: [
      NotificationChannel.inbox,
      NotificationChannel.push,
      NotificationChannel.inApp,
    ],
    priority: 4,
    entityType: 'job',
  ),
  'penalty_warning': NotificationContractEntry(
    type: 'penalty_warning',
    audienceRole: NotificationAudienceRole.technician,
    category: NotificationCategory.system,
    channels: [NotificationChannel.inbox, NotificationChannel.inApp],
    priority: 4,
    entityType: 'job',
  ),
  'stale_lock_recovered': NotificationContractEntry(
    type: 'stale_lock_recovered',
    audienceRole: NotificationAudienceRole.all,
    category: NotificationCategory.system,
    channels: [
      NotificationChannel.inbox,
      NotificationChannel.push,
      NotificationChannel.inApp,
    ],
    priority: 4,
    entityType: 'job',
  ),
  'new_job': NotificationContractEntry(
    type: 'new_job',
    audienceRole: NotificationAudienceRole.technician,
    category: NotificationCategory.job,
    channels: [NotificationChannel.inbox, NotificationChannel.inApp],
    priority: 4,
    entityType: 'job',
  ),
  'job_accepted': NotificationContractEntry(
    type: 'job_accepted',
    audienceRole: NotificationAudienceRole.customer,
    category: NotificationCategory.message,
    channels: [
      NotificationChannel.inbox,
      NotificationChannel.push,
      NotificationChannel.inApp,
    ],
    priority: 4,
    entityType: 'job',
  ),
  'price_set': NotificationContractEntry(
    type: 'price_set',
    audienceRole: NotificationAudienceRole.customer,
    category: NotificationCategory.offer,
    channels: [
      NotificationChannel.inbox,
      NotificationChannel.push,
      NotificationChannel.inApp,
    ],
    priority: 4,
    entityType: 'job',
  ),
  'price_pending': NotificationContractEntry(
    type: 'price_pending',
    audienceRole: NotificationAudienceRole.customer,
    category: NotificationCategory.offer,
    channels: [
      NotificationChannel.inbox,
      NotificationChannel.push,
      NotificationChannel.inApp,
    ],
    priority: 4,
    entityType: 'job',
  ),
  'completed': NotificationContractEntry(
    type: 'completed',
    audienceRole: NotificationAudienceRole.customer,
    category: NotificationCategory.payment,
    channels: [NotificationChannel.inbox, NotificationChannel.inApp],
    priority: 3,
    entityType: 'job',
  ),
  'warning': NotificationContractEntry(
    type: 'warning',
    audienceRole: NotificationAudienceRole.all,
    category: NotificationCategory.system,
    channels: [NotificationChannel.inbox],
    priority: 2,
  ),
};

NotificationContractEntry? notificationContractForType(String? type) {
  if (type == null || type.trim().isEmpty) {
    return null;
  }
  return notificationContractRegistry[type.trim()];
}

String normalizeNotificationCategory(String? category) {
  final value = category?.trim() ?? '';
  if (NotificationCategory.values.contains(value)) {
    return value;
  }
  return NotificationCategory.system;
}

String normalizeNotificationAudienceRole(String? role) {
  final value = role?.trim() ?? '';
  if (NotificationAudienceRole.values.contains(value)) {
    return value;
  }
  return NotificationAudienceRole.all;
}
