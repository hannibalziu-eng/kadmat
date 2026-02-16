class SubmitBidParams {
  final String jobId;
  final double amount;
  final String? notes;
  final int? estimatedDurationMinutes;
  final List<int>? availabilityDays;

  const SubmitBidParams({
    required this.jobId,
    required this.amount,
    this.notes,
    this.estimatedDurationMinutes,
    this.availabilityDays,
  });
}
