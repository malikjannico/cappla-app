import 'package:flutter/material.dart';

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  const AppColorsExtension({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
  });

  static const light = AppColorsExtension(
    success: Color(0xFF146947),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFF34825E),
    onSuccessContainer: Color(0xFFF6FFF6),
    warning: Color(0xFF725C00),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFCD445),
    onWarningContainer: Color(0xFF715B00),
  );

  static const dark = AppColorsExtension(
    success: Color(0xFF89D7AD),
    onSuccess: Color(0xFF003823),
    successContainer: Color(0xFF539F79),
    onSuccessContainer: Color(0xFF002012),
    warning: Color(0xFFFFF3D7),
    onWarning: Color(0xFF3C2F00),
    warningContainer: Color(0xFFFCD445),
    onWarningContainer: Color(0xFF715B00),
  );

  @override
  AppColorsExtension copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
  }) {
    return AppColorsExtension(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppColorsExtension get colors =>
      Theme.of(this).extension<AppColorsExtension>() ??
      AppColorsExtension.light;
}
