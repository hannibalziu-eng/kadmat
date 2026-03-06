import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Auth Design System Contract', () {
    const authScreens = <String>[
      'lib/src/features/auth/presentation/login_screen.dart',
      'lib/src/features/auth/presentation/register_screen.dart',
      'lib/src/features/auth/presentation/technician_login_screen.dart',
      'lib/src/features/auth/presentation/technician_register_screen.dart',
      'lib/src/features/auth/presentation/forgot_password_screen.dart',
    ];

    test('auth forms use KadmatTextField instead of raw TextFormField', () {
      for (final path in authScreens) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'File missing: $path');

        final source = file.readAsStringSync();

        expect(
          source.contains('KadmatTextField('),
          isTrue,
          reason: 'Expected KadmatTextField usage in $path',
        );
        expect(
          source.contains('TextFormField('),
          isFalse,
          reason: 'Raw TextFormField detected in $path',
        );
      }
    });
  });
}
