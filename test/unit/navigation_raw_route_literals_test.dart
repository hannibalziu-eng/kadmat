import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Navigation literals guard', () {
    test('no raw technician/job route literals in feature code', () {
      final root = Directory.current.path;
      final featuresDir = Directory('$root/lib/src/features');
      final allowedFiles = <String>{
        '$root/lib/src/core/navigation/app_routes.dart',
        '$root/lib/src/core/router/route_modules.dart',
      };

      final violations = <String>[];
      final pathRegex = RegExp(
        r"""(['"])(/(jobs/[^'"]*|active-job/[^'"]*|technician/(?:home|login|register|landing|waitlist-offer)[^'"]*|notifications|customer-wallet|login|register|welcome|forgot-password|tracking/[^'"]*))\1""",
      );

      for (final entity in featuresDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final normalizedPath = entity.path.replaceAll('\\', '/');
        final isPresentationFile = normalizedPath.contains('/presentation/');
        final isMainShellFile = normalizedPath.endsWith(
          '/features/main/main_screen.dart',
        );

        if (allowedFiles.contains(entity.path)) continue;
        if (normalizedPath.endsWith('_test.dart')) continue;
        if (normalizedPath.contains('/generated/')) continue;
        if (!isPresentationFile && !isMainShellFile) continue;

        final content = entity.readAsStringSync();

        for (final match in pathRegex.allMatches(content)) {
          final line =
              '\n'.allMatches(content.substring(0, match.start)).length + 1;
          violations.add('${entity.path}:$line -> ${match.group(2)}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Raw route literals found. Use AppRoutes constants/builders.\n'
            '${violations.join('\n')}',
      );
    });
  });
}
