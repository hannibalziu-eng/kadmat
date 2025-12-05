import 'package:flutter/material.dart';

/// A mixin to help with memory management in StatefulWidgets.
/// It provides a standard way to track and dispose objects.
mixin AutoDisposeMixin<T extends StatefulWidget> on State<T> {
  final List<ChangeNotifier> _disposables = [];

  /// Registers a ChangeNotifier to be automatically disposed.
  T register<T extends ChangeNotifier>(T disposable) {
    _disposables.add(disposable);
    return disposable;
  }

  @override
  void dispose() {
    for (final disposable in _disposables) {
      disposable.dispose();
    }
    super.dispose();
  }
}
