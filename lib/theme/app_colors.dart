import 'package:flutter/material.dart';

/// Centralized semantic color tokens para sa buong app. Sa halip na
/// mag-hardcode ng Color(0xFF...) sa bawat page, kunin na lang dito
/// (via `context.colors.xxx`) — automatic na itong nagbabago pag
/// nag-toggle ng dark mode dahil naka-attach ito sa ThemeData bilang
/// ThemeExtension.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.primary,
    required this.primaryLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.chipBg,
    required this.border,
    required this.borderStrong,
    required this.shadow,
    required this.shadowStrong,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.error,
    required this.errorBg,
    required this.errorBorder,
    required this.neutral,
    required this.neutralBg,
    required this.inputFill,
    required this.inputBorder,
    required this.statusInProgress,
    required this.statusInProgressBg,
    required this.statusReady,
    required this.statusReadyBg,
  });

  final Color background;
  final Color surface;
  final Color primary;
  final Color primaryLight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color chipBg;
  final Color border;
  final Color borderStrong;
  final Color shadow;
  final Color shadowStrong;
  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color error;
  final Color errorBg;
  final Color errorBorder;
  final Color neutral;
  final Color neutralBg;
  final Color inputFill;
  final Color inputBorder;
  final Color statusInProgress;
  final Color statusInProgressBg;
  final Color statusReady;
  final Color statusReadyBg;

  static const light = AppColors(
    background: Color(0xFFEFF8FF),
    surface: Colors.white,
    primary: Color(0xFF0EA5E9),
    primaryLight: Color(0xFF38BDF8),
    textPrimary: Color(0xFF075985),
    textSecondary: Color(0xFF4B7A99),
    textMuted: Color(0xFF94A3B8),
    chipBg: Color(0xFFDDF2FF),
    border: Color(0xFFE5F0FA),
    borderStrong: Color(0xFFBAE6FD),
    shadow: Color(0x0F0D3B78),
    shadowStrong: Color(0x160D3B78),
    success: Color(0xFF16A34A),
    successBg: Color(0xFFDCFCE7),
    warning: Color(0xFFB45309),
    warningBg: Color(0xFFFEF3C7),
    error: Color(0xFFDC5B4F),
    errorBg: Color(0xFFFFE4E1),
    errorBorder: Color(0xFFFFD4D0),
    neutral: Color(0xFF64748B),
    neutralBg: Color(0xFFF1F5F9),
    inputFill: Color(0xFFF8FCFF),
    inputBorder: Color(0xFFB8DDF5),
    statusInProgress: Color(0xFF0284C7),
    statusInProgressBg: Color(0xFFDDF2FF),
    statusReady: Color(0xFF0369A1),
    statusReadyBg: Color(0xFFE0F2FE),
  );

  static const dark = AppColors(
    background: Color(0xFF0B1220),
    surface: Color(0xFF111C2E),
    primary: Color(0xFF38BDF8),
    primaryLight: Color(0xFF7DD3FC),
    textPrimary: Color(0xFFE0F2FE),
    textSecondary: Color(0xFF93B4CC),
    textMuted: Color(0xFF64748B),
    chipBg: Color(0xFF13324A),
    border: Color(0xFF1E3A52),
    borderStrong: Color(0xFF2B4E6E),
    shadow: Color(0x33000000),
    shadowStrong: Color(0x4D000000),
    success: Color(0xFF4ADE80),
    successBg: Color(0xFF14321F),
    warning: Color(0xFFFBBF24),
    warningBg: Color(0xFF3A2E10),
    error: Color(0xFFF87171),
    errorBg: Color(0xFF3A1917),
    errorBorder: Color(0xFF5C2624),
    neutral: Color(0xFF94A3B8),
    neutralBg: Color(0xFF1E293B),
    inputFill: Color(0xFF16233A),
    inputBorder: Color(0xFF2B4E6E),
    statusInProgress: Color(0xFF38BDF8),
    statusInProgressBg: Color(0xFF13324A),
    statusReady: Color(0xFF7DD3FC),
    statusReadyBg: Color(0xFF13324A),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? primary,
    Color? primaryLight,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? chipBg,
    Color? border,
    Color? borderStrong,
    Color? shadow,
    Color? shadowStrong,
    Color? success,
    Color? successBg,
    Color? warning,
    Color? warningBg,
    Color? error,
    Color? errorBg,
    Color? errorBorder,
    Color? neutral,
    Color? neutralBg,
    Color? inputFill,
    Color? inputBorder,
    Color? statusInProgress,
    Color? statusInProgressBg,
    Color? statusReady,
    Color? statusReadyBg,
  }) =>
      AppColors(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        primary: primary ?? this.primary,
        primaryLight: primaryLight ?? this.primaryLight,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
        chipBg: chipBg ?? this.chipBg,
        border: border ?? this.border,
        borderStrong: borderStrong ?? this.borderStrong,
        shadow: shadow ?? this.shadow,
        shadowStrong: shadowStrong ?? this.shadowStrong,
        success: success ?? this.success,
        successBg: successBg ?? this.successBg,
        warning: warning ?? this.warning,
        warningBg: warningBg ?? this.warningBg,
        error: error ?? this.error,
        errorBg: errorBg ?? this.errorBg,
        errorBorder: errorBorder ?? this.errorBorder,
        neutral: neutral ?? this.neutral,
        neutralBg: neutralBg ?? this.neutralBg,
        inputFill: inputFill ?? this.inputFill,
        inputBorder: inputBorder ?? this.inputBorder,
        statusInProgress: statusInProgress ?? this.statusInProgress,
        statusInProgressBg: statusInProgressBg ?? this.statusInProgressBg,
        statusReady: statusReady ?? this.statusReady,
        statusReadyBg: statusReadyBg ?? this.statusReadyBg,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      chipBg: Color.lerp(chipBg, other.chipBg, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      shadowStrong: Color.lerp(shadowStrong, other.shadowStrong, t)!,
      success: Color.lerp(success, other.success, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorBg: Color.lerp(errorBg, other.errorBg, t)!,
      errorBorder: Color.lerp(errorBorder, other.errorBorder, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      neutralBg: Color.lerp(neutralBg, other.neutralBg, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      statusInProgress: Color.lerp(statusInProgress, other.statusInProgress, t)!,
      statusInProgressBg: Color.lerp(statusInProgressBg, other.statusInProgressBg, t)!,
      statusReady: Color.lerp(statusReady, other.statusReady, t)!,
      statusReadyBg: Color.lerp(statusReadyBg, other.statusReadyBg, t)!,
    );
  }
}

/// Shortcut: `context.colors.textPrimary` sa halip na
/// `Theme.of(context).extension<AppColors>()!.textPrimary`.
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}