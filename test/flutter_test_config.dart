import 'dart:async';

import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GlobalResponsive.update(ResponsiveData.identity());
  await testMain();
}
