class CreateDisputeParams {
  final String jobId;
  final String disputeType;
  final String description;
  final List<String>? photoUrls;

  const CreateDisputeParams({
    required this.jobId,
    required this.disputeType,
    required this.description,
    this.photoUrls,
  });
}
