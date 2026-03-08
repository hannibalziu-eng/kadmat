import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_repository.dart';
import '../../notifications/data/push_notification_service.dart';

part 'auth_controller.g.dart';

@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<void> build() {
    // nothing to do
  }

  Future<bool> signIn({
    required String email,
    required String password,
    String? requiredUserType,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _authenticate(email, password, requiredUserType),
    );
    return state.hasError == false;
  }

  Future<void> _authenticate(
    String email,
    String password,
    String? requiredUserType,
  ) async {
    final authRepository = ref.read(authRepositoryProvider);
    await authRepository.signInWithEmailAndPassword(
      email,
      password,
      requiredUserType: requiredUserType,
    );
    // Register push token if available (must not block login flow).
    try {
      await ref.read(pushNotificationServiceProvider).registerCurrentToken();
    } catch (_) {
      // Keep auth flow resilient when Firebase push is not configured.
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String phone,
    required String fullName,
    String userType = 'customer',
    String? serviceId,
    List<String>? documentUrls,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _register(
        email: email,
        password: password,
        phone: phone,
        fullName: fullName,
        userType: userType,
        serviceId: serviceId,
        documentUrls: documentUrls,
      ),
    );
    return state.hasError == false;
  }

  Future<void> _register({
    required String email,
    required String password,
    required String phone,
    required String fullName,
    required String userType,
    String? serviceId,
    List<String>? documentUrls,
  }) async {
    final authRepository = ref.read(authRepositoryProvider);
    await authRepository.register(
      email: email,
      password: password,
      phone: phone,
      fullName: fullName,
      userType: userType,
      serviceId: serviceId,
      documentUrls: documentUrls,
    );
    // Register push token if available (must not block signup flow).
    try {
      await ref.read(pushNotificationServiceProvider).registerCurrentToken();
    } catch (_) {
      // Keep auth flow resilient when Firebase push is not configured.
    }
  }

  Future<bool> sendPasswordResetEmail({required String email}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () =>
          ref.read(authRepositoryProvider).sendPasswordResetEmail(email: email),
    );
    return state.hasError == false;
  }

  Future<bool> signInAsGuest() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authenticateAsGuest());
    return state.hasError == false;
  }

  Future<void> _authenticateAsGuest() {
    final authRepository = ref.read(authRepositoryProvider);
    return authRepository.signInAsGuest();
  }
}

@riverpod
Future<List<Map<String, dynamic>>> activeServices(Ref ref) async {
  try {
    final response = await Supabase.instance.client
        .from('services')
        .select('id, name, name_ar')
        .eq('is_active', true);

    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    return [];
  }
}
