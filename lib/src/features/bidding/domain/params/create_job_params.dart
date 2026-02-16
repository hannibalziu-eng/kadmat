class CreateJobParams {
  final String serviceId;
  final String description;
  final double latitude;
  final double longitude;
  final String address;
  final String? addressDetails;
  final double? maxBudget;
  final DateTime? preferredTime;

  const CreateJobParams({
    required this.serviceId,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.addressDetails,
    this.maxBudget,
    this.preferredTime,
  });
}
