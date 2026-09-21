import 'package:flutter/material.dart';

import '../screens/splash_page.dart';
import '../theme/app_colors.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative blobs — nakabase sa parehong "bubbles" tema ng
            // Home page banner, para consistent ang illustrated na
            // itsura sa buong app.
            Positioned(
              top: -40,
              right: -50,
              child: _blob(160, colors.primary.withValues(alpha: 0.08)),
            ),
            Positioned(
              top: 120,
              left: -60,
              child: _blob(120, colors.primaryLight.withValues(alpha: 0.1)),
            ),
            Positioned(
              bottom: -60,
              right: -30,
              child: _blob(180, colors.primary.withValues(alpha: 0.06)),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                tooltip: 'Back to welcome',
                icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      const LaundryLinkLogo(fontSize: 24),
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(color: colors.shadowStrong, blurRadius: 26, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: child,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}