import 'package:flutter/material.dart';

import '../screens/splash_page.dart';
import '../theme/app_colors.dart';

/// UPDATED (bug fix + UI polish) — staggered entrance animation (logo →
/// card), gradient background + layered blobs, at FIX sa back button:
/// gumagamit na ng Listener (hindi GestureDetector.onTap) para sa
/// "press down" effect, habang ang IconButton mismo ang may totoong
/// onPressed. Dati, ang GestureDetector.onTap ang may hawak ng
/// navigation habang naka onPressed:null ang IconButton — minsan
/// nagkaka-conflict sa gesture arena kaya di gumagana ang pindot.
class AuthLayout extends StatefulWidget {
  const AuthLayout({super.key, required this.child});
  final Widget child;

  @override
  State<AuthLayout> createState() => _AuthLayoutState();
}

class _AuthLayoutState extends State<AuthLayout> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Animation<double> _fadeFor(double start, double end) => CurvedAnimation(
        parent: _entrance,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );

  Widget _staggered({required double start, required double end, required Widget child}) {
    final fade = _fadeFor(start, end);
    return AnimatedBuilder(
      animation: fade,
      builder: (context, _) => Opacity(
        opacity: fade.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - fade.value) * 16),
          child: child,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.primary.withOpacity(0.10),
              colors.background,
              colors.background,
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -40,
                right: -50,
                child: _Blob(color: colors.primary.withOpacity(0.14), size: 180),
              ),
              Positioned(
                top: 120,
                left: -60,
                child: _Blob(color: colors.primaryLight.withOpacity(0.10), size: 130),
              ),
              Positioned(
                bottom: -60,
                right: -30,
                child: _Blob(color: colors.primary.withOpacity(0.08), size: 200),
              ),
              Positioned(
                bottom: 140,
                left: -40,
                child: _Blob(color: colors.primary.withOpacity(0.06), size: 120),
              ),
              const Positioned(top: 90, right: 70, child: _TinyBubble(size: 8)),
              const Positioned(bottom: 200, left: 56, child: _TinyBubble(size: 6)),
              Positioned(
                top: 8,
                left: 8,
                child: _TapScale(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: colors.shadowStrong, blurRadius: 10, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: IconButton(
                      tooltip: 'Back to welcome',
                      icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
                      // FIX: totoong onPressed na dito mismo, hindi na
                      // umaasa sa outer GestureDetector.
                      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    ),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: [
                        _staggered(
                          start: 0.0,
                          end: 0.5,
                          child: const LaundryLinkLogo(fontSize: 24),
                        ),
                        const SizedBox(height: 30),
                        _staggered(
                          start: 0.15,
                          end: 0.75,
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(color: colors.shadowStrong, blurRadius: 26, offset: const Offset(0, 8)),
                              ],
                            ),
                            child: widget.child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _TinyBubble extends StatelessWidget {
  const _TinyBubble({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primary.withOpacity(0.18),
        border: Border.all(color: colors.primary.withOpacity(0.25), width: 1),
      ),
    );
  }
}

/// FIX: Listener na lang (raw pointer, walang tap-arena participation)
/// para sa "press down" visual scale. Ang totoong onPressed ay nasa
/// IconButton/FilledButton mismo sa loob ng child.
class _TapScale extends StatefulWidget {
  const _TapScale({required this.child});
  final Widget child;

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}