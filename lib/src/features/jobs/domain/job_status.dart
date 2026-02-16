/// Defines the various statuses a Job can be in throughout its lifecycle.
class JobStatus {
  // Canonical backend states
  static const String pending = 'pending';
  static const String searching = 'searching';
  static const String accepted = 'accepted';
  static const String pricePending = 'price_pending';
  static const String onTheWay = 'on_the_way';
  static const String arrived = 'arrived';
  static const String inProgress = 'in_progress';
  static const String pendingConfirm = 'pending_confirm';
  static const String completed = 'completed';
  static const String rated = 'rated';
  static const String cancelled = 'cancelled';
  static const String noTechnicianFound = 'no_technician_found';

  // Legacy aliases kept for compatibility with older UI code
  static const String acceptedByTech = accepted;
  static const String priceSent = pricePending;
  static const String customerAgreed = 'customer_agreed';
  static const String paymentPending = pendingConfirm;
  static const String paid = 'paid';
  static const String reviewed = rated;

  /// Normalize legacy/alternate statuses into canonical backend states.
  static String normalize(String status) {
    switch (status) {
      case 'accepted_by_tech':
        return accepted;
      case 'price_sent':
        return pricePending;
      case 'customer_agreed':
        return inProgress;
      case 'technician_on_the_way':
        return onTheWay;
      case 'technician_arrived':
        return arrived;
      case 'payment_pending':
      case 'pending_confirmation':
        return pendingConfirm;
      case 'reviewed':
        return rated;
      case 'no_technician':
        return noTechnicianFound;
      default:
        return status;
    }
  }
}
