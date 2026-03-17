import 'package:flutter/material.dart';

import 'kadmat_tokens.dart';

@immutable
class KadmatSemanticColors extends ThemeExtension<KadmatSemanticColors> {
  const KadmatSemanticColors({
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.softOverlay,
  });

  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color softOverlay;

  const KadmatSemanticColors.dark()
    : this(
        success: KadmatColors.stateSuccess,
        warning: KadmatColors.stateWarning,
        error: KadmatColors.stateError,
        info: KadmatColors.stateInfo,
        softOverlay: const Color(0xB3101D22),
      );

  const KadmatSemanticColors.light()
    : this(
        success: KadmatColors.stateSuccess,
        warning: KadmatColors.stateWarning,
        error: KadmatColors.stateError,
        info: KadmatColors.stateInfo,
        softOverlay: const Color(0xB3F9FAFB),
      );

  @override
  KadmatSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? softOverlay,
  }) {
    return KadmatSemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      softOverlay: softOverlay ?? this.softOverlay,
    );
  }

  @override
  KadmatSemanticColors lerp(
    ThemeExtension<KadmatSemanticColors>? other,
    double t,
  ) {
    if (other is! KadmatSemanticColors) {
      return this;
    }

    return KadmatSemanticColors(
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      error: Color.lerp(error, other.error, t) ?? error,
      info: Color.lerp(info, other.info, t) ?? info,
      softOverlay: Color.lerp(softOverlay, other.softOverlay, t) ?? softOverlay,
    );
  }
}
