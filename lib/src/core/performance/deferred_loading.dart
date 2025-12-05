import 'package:flutter/material.dart';

/// A widget that handles the loading state of a deferred library.
class DeferredLoader extends StatelessWidget {
  final Future<void> Function() loadLibrary;
  final WidgetBuilder builder;
  final Widget? placeholder;

  const DeferredLoader({
    super.key,
    required this.loadLibrary,
    required this.builder,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: loadLibrary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return builder(context);
        }
        return placeholder ??
            const Center(child: CircularProgressIndicator.adaptive());
      },
    );
  }
}
