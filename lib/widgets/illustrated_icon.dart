import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Reusable "illustrated" icon badge — layered concentric circles sa
/// likod ng isang icon, para hindi flat/plain ang tingin sa empty
/// states at banners sa buong app. Walang image assets, gawa lang sa
/// Container/Circle shapes.
///
/// Halimbawa: `IllustratedIcon(icon: Icons.receipt_long_outlined)`
class IllustratedIcon extends StatelessWidget {
  const IllustratedIcon({
    super.key,
    required this.icon,
    this.size = 96,
    this.color,
    this.backgroundColor,
  });

  final IconData icon;
  final double size;

  /// Kulay ng icon mismo at ng pinakaloob na circle. Defaults sa
  /// colors.primary kung hindi binigyan.
  final Color? color;

  /// Base color ng mga concentric circles sa likod. Defaults din sa
  /// colors.primary (naka-opacity lang, kaya soft ang itsura).
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color iconColor = color ?? colors.primary;
    final Color baseColor = backgroundColor ?? colors.primary;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: baseColor.withValues(alpha: 0.08), shape: BoxShape.circle),
          ),
          Container(
            width: size * 0.74,
            height: size * 0.74,
            decoration: BoxDecoration(color: baseColor.withValues(alpha: 0.14), shape: BoxShape.circle),
          ),
          Container(
            width: size * 0.5,
            height: size * 0.5,
            decoration: BoxDecoration(color: baseColor.withValues(alpha: 0.2), shape: BoxShape.circle),
          ),
          Icon(icon, size: size * 0.34, color: iconColor),
          // Small accent dots — nagbibigay ng "sprinkle" na feeling sa
          // halip na perpektong symmetric lang.
          Positioned(
            top: size * 0.08,
            right: size * 0.12,
            child: Container(
              width: size * 0.09,
              height: size * 0.09,
              decoration: BoxDecoration(color: baseColor.withValues(alpha: 0.3), shape: BoxShape.circle),
            ),
          ),
          Positioned(
            bottom: size * 0.1,
            left: size * 0.06,
            child: Container(
              width: size * 0.06,
              height: size * 0.06,
              decoration: BoxDecoration(color: baseColor.withValues(alpha: 0.25), shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pares ng IllustratedIcon + title + (optional) message — ready-made
/// empty state layout. Gagamitin natin ito sa History, Notifications,
/// Saved Addresses, atbp. para consistent lahat ng empty states.
class IllustratedEmptyState extends StatelessWidget {
  const IllustratedEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.iconColor,
    this.iconBackgroundColor,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IllustratedIcon(icon: icon, color: iconColor, backgroundColor: iconBackgroundColor),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.textPrimary),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, height: 1.4),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}