import 'package:image_picker/image_picker.dart';
import '../domain/job.dart';

abstract class IJobRepository {
  /// Fetch nearby jobs using Supabase RPC
  Future<List<Job>> getNearbyJobsRpc({
    required double lat,
    required double lng,
    int radiusMeters = 5000,
    int limit = 50,
    String? serviceId,
  });

  /// Create a new job
  Future<Job?> createJob({
    required String serviceId,
    required double lat,
    required double lng,
    required String addressText,
    required double initialPrice,
    String? description,
    List<String>? images,
  });

  /// Get job details by ID
  Future<Job?> getJobById(String jobId);

  /// Get nearby jobs (Legacy/Direct)
  Future<List<Job>> getNearbyJobs({
    required double lat,
    required double lng,
    double radius = 5000,
  });

  /// Get signed-in user's jobs
  Future<List<Job>> getMyJobs();

  /// Accept a job
  Future<Job> acceptJob(String jobId);

  /// Set job price
  Future<Job> setPrice(
    String jobId,
    double price, {
    String? notes,
    String? paymentMethod,
  });

  /// Confirm job price
  Future<Job> confirmPrice(String jobId);

  /// Update technician progress after price confirmation.
  /// Supported progress actions: `arrived`, `start_work`.
  Future<Job> updateTechnicianProgress(
    String jobId, {
    required String progress,
  });

  /// Request job completion
  Future<Job> requestJobCompletion(
    String jobId, {
    double? finalPrice,
    String? paymentMethod,
    String? notes,
    List<String>? afterPhotos,
  });

  /// Confirm job completion
  Future<Job> confirmJobCompletion(String jobId);

  /// Rate a job
  Future<Job> rateJob(String jobId, int rating, {String? review});

  /// Cancel a job
  Future<void> cancelJob(String jobId, {String? reason});

  // Watchers
  Stream<Job> watchJob(String jobId);
  Stream<List<Job>> watchMyActiveJobs(String userId);
  Stream<Map<String, dynamic>> trackTechnician(String technicianId);
  Stream<bool> watchTechnicianLockStatus(String userId);

  // Photos
  Future<List<String>> uploadPreServicePhotos(
    String jobId,
    List<XFile> photos,
    String description,
  );

  Future<List<String>> uploadPostServicePhotos(
    String jobId,
    List<XFile> photos,
    String notes,
  );

  Future<Map<String, List<String>>> getJobPhotos(String jobId);
}
