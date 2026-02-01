/// Defines the various statuses a Job can be in throughout its lifecycle.
class JobStatus {
  // Phase 1: Request
  static const String pending = 'pending';

  // Phase 2: Technician Handling
  static const String acceptedByTech =
      'accepted_by_tech'; // Tech accepted, needs to set price
  static const String priceSent = 'price_sent'; // Tech sent price

  // Phase 3: Agreement
  static const String customerAgreed =
      'customer_agreed'; // Customer approved price
  static const String inProgress = 'in_progress'; // Tech started working

  // Phase 4: Completion
  static const String completed = 'completed'; // Tech marked as complete

  // Phase 5: Payment
  static const String paymentPending =
      'payment_pending'; // Waiting for customer payment
  static const String paid = 'paid'; // Payment successful

  // Phase 6: Review & End
  static const String reviewed = 'reviewed'; // Rated by customer
  static const String cancelled = 'cancelled';

  // Legacy/Compatibility (Map these to new flow if needed)
  static const String searching = 'searching';
  static const String accepted = 'accepted'; // Maps to acceptedByTech usually
  static const String pricePending = 'price_pending'; // Maps to acceptedByTech
  static const String rated = 'rated'; // Maps to reviewed
}
