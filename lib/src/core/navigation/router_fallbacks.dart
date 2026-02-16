import 'app_routes.dart';

const Set<String> kKnownTechnicianJobFlowSteps = {
  'detail',
  'accepted',
  'set-price',
  'waiting',
  'in-progress',
  'completed',
  'pre-photos',
  'post-photos',
  'price-confirmation',
  'complete-work-input',
  'bidding',
};

String? resolveUnknownTechnicianJobPath(String location) {
  final match = RegExp(
    r'^/jobs/([^/]+)/technician/([^/]+)$',
  ).firstMatch(location);

  if (match == null) return null;

  final jobId = match.group(1);
  final step = match.group(2);
  if (jobId == null || jobId.isEmpty || step == null || step.isEmpty) {
    return null;
  }

  if (kKnownTechnicianJobFlowSteps.contains(step)) {
    return null;
  }

  return AppRoutes.buildTechnicianJobDetailPath(jobId);
}

String resolveUnknownRouteFallback({
  required String location,
  required bool isTechnicianUser,
}) {
  if (!isTechnicianUser) {
    return AppRoutes.home;
  }

  return resolveUnknownTechnicianJobPath(location) ?? AppRoutes.technicianHome;
}
