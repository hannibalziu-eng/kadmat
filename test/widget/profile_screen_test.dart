import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/features/auth/data/auth_repository.dart';
import 'package:kadmat/src/features/profile/presentation/profile_screen.dart';
import 'package:kadmat/src/features/wallet/domain/wallet.dart';
import 'package:kadmat/src/features/wallet/presentation/wallet_controller.dart';
import 'package:mockito/mockito.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  testWidgets(
    'ProfileScreen shows real wallet data and no hard-coded balance',
    (tester) async {
      final authRepository = MockAuthRepository();
      when(authRepository.currentUser).thenReturn('customer-1');
      when(
        authRepository.userProfile,
      ).thenReturn({'full_name': 'عميل حقيقي', 'phone': '0912345678'});

      final wallet = Wallet(
        id: 'wallet-1',
        userId: 'customer-1',
        balance: 125.5,
        currency: 'SAR',
        createdAt: DateTime(2026, 3, 7),
        updatedAt: DateTime(2026, 3, 7),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepository),
            myWalletProvider.overrideWith((ref) async => wallet),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('عميل حقيقي'), findsOneWidget);
      expect(find.textContaining('125.50 SAR'), findsOneWidget);
      expect(find.textContaining('350.00'), findsNothing);
    },
  );
}
