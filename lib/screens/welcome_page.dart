import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'splash_page.dart';

/// UPDATED (UI polish) — dating StatelessWidget, ngayon may staggered
/// entrance animation (logo → wordmark → buttons, isa-isa fade + slide
/// pataas). Background ay gradient na ngayon (hindi na plain white),
/// may malalaking soft blobs at isang subtle bubble-texture layer para
/// mas "illustrated" ang itsura, tugma sa laundry/bubbles theme ng app.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _fadeFor(double start, double end) => CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );

  Widget _staggered({required double start, required double end, required Widget child}) {
    final fade = _fadeFor(start, end);
    return AnimatedBuilder(
      animation: fade,
      builder: (context, _) => Opacity(
        opacity: fade.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - fade.value) * 18),
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
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Decorative blobs — layered, varying size/opacity for depth.
            Positioned(
              top: -70,
              right: -50,
              child: _Blob(color: colors.primary.withOpacity(0.14), size: 240),
            ),
            Positioned(
              top: 40,
              left: -80,
              child: _Blob(color: colors.primary.withOpacity(0.08), size: 180),
            ),
            Positioned(
              bottom: -90,
              left: -60,
              child: _Blob(color: colors.primary.withOpacity(0.10), size: 280),
            ),
            Positioned(
              bottom: 120,
              right: -40,
              child: _Blob(color: colors.primary.withOpacity(0.06), size: 140),
            ),
            // Small floating "bubble" accents for texture.
            const Positioned(top: 90, left: 48, child: _TinyBubble(size: 10)),
            const Positioned(top: 160, right: 64, child: _TinyBubble(size: 6)),
            const Positioned(bottom: 220, right: 90, child: _TinyBubble(size: 8)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    _staggered(
                      start: 0.0,
                      end: 0.55,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.surface,
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withOpacity(0.18),
                                blurRadius: 32,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/Untitled design.png',
                            width: 95,
                            height: 95,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _staggered(
                      start: 0.2,
                      end: 0.7,
                      child: const Center(
                        child: LaundryLinkLogo(fontSize: 32),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _staggered(
                      start: 0.25,
                      end: 0.75,
                      child: Center(
                        child: Text(
                          'We pick up the dirty, we deliver the fresh.',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _staggered(
                      start: 0.4,
                      end: 0.9,
                      child: _TapScale(
                        onTap: () => Navigator.of(context).push(_fadeSlideRoute(const LoginPage())),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withOpacity(0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: FilledButton(
                            onPressed: null, // handled by _TapScale's GestureDetector
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              backgroundColor: colors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: colors.primary,
                              disabledForegroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('Login', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _staggered(
                      start: 0.55,
                      end: 1.0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(_fadeSlideRoute(const RegisterPage())),
                            child: Text(
                              'Sign up',
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
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

/// NEW — tiny static bubble accent, reinforces the laundry/bubbles
/// visual theme without any animation overhead.
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

/// "press down" scale effect (98%) sa mga pangunahing buttons.
class _TapScale extends StatefulWidget {
  const _TapScale({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

/// fade + slight upward-slide na page transition, papalit sa default na
/// MaterialPageRoute para sa Welcome → Login / Register navigation.
Route<T> _fadeSlideRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );