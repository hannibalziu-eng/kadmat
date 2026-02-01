import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/technician_repository.dart';
import '../domain/technician_profile.dart';

part 'technician_profile_controller.g.dart';

@riverpod
Future<TechnicianProfile> technicianProfile(Ref ref, String technicianId) {
  return ref
      .watch(technicianRepositoryProvider)
      .getTechnicianProfile(technicianId);
}
