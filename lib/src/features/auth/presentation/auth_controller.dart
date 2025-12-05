import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/auth_repository.dart';

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
        () => _authenticate(email, password, requiredUserType));
    return state.hasError == false;
  }

  Future<void> _authenticate(
      String email, String password, String? requiredUserType) {
    final authRepository = ref.read(authRepositoryProvider);
    return authRepository.signInWithEmailAndPassword(
      email,
      password,
      requiredUserType: requiredUserType,
    );
  }

  Future<bool> register({
    required String email,
    required String password,
    required String phone,
    required String fullName,
    String userType = 'customer',
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _register(
        email: email,
        password: password,
        phone: phone,
        fullName: fullName,
        userType: userType,
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
  }) {
    final authRepository = ref.read(authRepositoryProvider);
    return authRepository.register(
      email: email,
      password: password,
      phone: phone,
      fullName: fullName,
      userType: userType,
    );
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
