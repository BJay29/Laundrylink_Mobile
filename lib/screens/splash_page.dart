import 'package:flutter/material.dart';

import '../services/customer_session.dart';
import '../theme/app_colors.dart';
import 'main_nav_page.dart';
import 'welcome_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

/// UPDATED (UI polish v3) — logo-na-lang na ang laman ng splash, wala nang
/// "LaundryLink" wordmark / tagline. Dalawang controller na lang:
///
///  1. `_logoInCtrl` — logo scale+fade in na may soft "settle"/overshoot
///     (easeOutBack), kapareho pa rin ng dati.
///  2. Habang naghihintay ng `restoreSession()` (may guaranteed minimum
///     hold duration para hindi "kumurap" lang sa mabilis na koneksyon),
///     nananatili lang ang logo + maliit na loading indicator.
///  3. `_zoomCtrl` — dramatic zoom-in ng logo papalapit sa dulo, habang
///     unti-unting nagfa-fade out ang buong splash content papunta sa
///     susunod na page.
///  4. `_fadeSlideRoute` pa rin ang ginagamit papunta sa MainNavPage o
///     WelcomePage — hindi biglaang MaterialPageRoute.
///
/// Logo sizing: ginawang mas maliit ang Image (96x96) kaysa sa puting
/// bilog na container nito (150x150), at naka-`ClipOval` ang image sa
/// loob ng eksaktong parehong bilog — para kahit may sarili pang puting
/// gilid/border ang source PNG mismo, hindi na ito lalampas o makikita
/// sa labas ng bilog; laging nasa loob at "nakatago" sa puting background.
///
/// Walang binago sa restoreSession()/bootstrap decision logic.
class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _logoInCtrl;
  late final AnimationController _zoomCtrl;

  static const _logoInDuration = Duration(milliseconds: 650);
  static const _zoomDuration = Duration(milliseconds: 650);
  static const _minHold = Duration(milliseconds: 900);

  static const double _zoomFactor = 6.5;

  // Puting bilog na "frame" ng logo.
  static const double _circleSize = 150;
  // Ang laman/artwork mismo — sadyang mas maliit sa bilog para hindi
  // makita ang puting border/gilid ng source image.
  static const double _logoSize = 96;

  @override
  void initState() {
    super.initState();
    _logoInCtrl = AnimationController(vsync: this, duration: _logoInDuration);
    _zoomCtrl = AnimationController(vsync: this, duration: _zoomDuration);
    _bootstrap();
  }

  @override
  void dispose() {
    _logoInCtrl.dispose();
    _zoomCtrl.dispose();
    super.dispose();
  }

  /// Sequence: logo in -> hold habang naghihintay ng restoreSession()
  /// (may minimum na `_minHold`) -> logo zoom-in + fade-out -> navigate.
  Future<void> _bootstrap() async {
    final sessionFuture = CustomerSession.instance.restoreSession();

    // 1. Logo settles in.
    await _logoInCtrl.forward();
    if (!mounted) return;

    // 2. Hold habang hinihintay ang session restore, may guaranteed
    // minimum duration para hindi "kumurap" lang sa mabilis na koneksyon.
    await Future.wait([
      Future.delayed(_minHold),
      sessionFuture,
    ]);
    if (!mounted) return;

    // 3. Dramatic zoom-in ng logo + fade-out ng buong splash.
    await _zoomCtrl.forward();
    if (!mounted) return;

    // 4. Navigate — parehong fade+slide transition gaya ng dati.
    final customer = CustomerSession.instance.customer;
    if (customer != null) {
      Navigator.of(context).pushReplacement(
        _fadeSlideRoute(MainNavPage(customer: customer)),
      );
    } else {
      Navigator.of(context).pushReplacement(
        _fadeSlideRoute(const WelcomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // --- Phase 1: logo entrance (scale+fade, overshoot) ---
    final logoInScale = CurvedAnimation(parent: _logoInCtrl, curve: Curves.easeOutBack);
    final logoInFade = CurvedAnimation(
      parent: _logoInCtrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    // --- Phase 3: dramatic zoom-in ng logo + fade-out ng buong splash ---
    final zoomScaleAnim = CurvedAnimation(parent: _zoomCtrl, curve: Curves.easeInCubic);
    final splashFadeOutAnim = CurvedAnimation(
      parent: _zoomCtrl,
      curve: const Interval(0.55, 1.0, curve: Curves.easeIn),
    );

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
            // Decorative blobs — parehong pattern ng welcome_page.dart.
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
            // Buong splash content — nagfa-fade out papunta sa dulo ng
            // zoom phase para sumabay sa page transition.
            AnimatedBuilder(
              animation: splashFadeOutAnim,
              builder: (context, child) => Opacity(
                opacity: (1 - splashFadeOutAnim.value).clamp(0.0, 1.0),
                child: child,
              ),
              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // --- LOGO lang, walang text ---
                      // Combined scale: entrance overshoot (phase 1) *
                      // dramatic zoom-in multiplier (phase 3).
                      AnimatedBuilder(
                        animation: Listenable.merge([logoInScale, logoInFade, zoomScaleAnim]),
                        builder: (context, child) {
                          final entranceScale = logoInScale.value.clamp(0.0, 1.15);
                          final zoomMultiplier = 1.0 + zoomScaleAnim.value * (_zoomFactor - 1.0);
                          return Opacity(
                            opacity: logoInFade.value.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: entranceScale * zoomMultiplier,
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          width: _circleSize,
                          height: _circleSize,
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
                          // ClipOval sa eksaktong parehong bilog para
                          // guaranteed na "nakatago" sa loob ang image —
                          // kahit may sarili pang puting gilid/border ang
                          // source PNG, hindi ito lalabas sa labas ng
                          // bilog dahil mas maliit at naka-clip ito.
                          child: ClipOval(
                            child: Center(
                              child: Image.asset(
                                'assets/images/Untitled design.png',
                                width: _logoSize,
                                height: _logoSize,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 56),
                      // --- Maliit na loading indicator habang naghihintay
                      // ng session restore. ---
                      AnimatedBuilder(
                        animation: logoInFade,
                        builder: (context, child) => Opacity(
                          opacity: logoInFade.value.clamp(0.0, 1.0),
                          child: child,
                        ),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(colors.primary.withOpacity(0.6)),
                          ),
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

/// fade + slight upward-slide na page transition, parehong pattern ng
/// welcome_page.dart / login_page.dart / register_page.dart.
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

/// Iniwan ang LaundryLinkLogo widget (ginagamit pa rin siguro sa ibang
/// page tulad ng welcome_page.dart) — hindi na lang ito ginagamit dito
/// sa splash screen.
class LaundryLinkLogo extends StatelessWidget {
  const LaundryLinkLogo({
    super.key,
    required this.fontSize,
  });

  final double fontSize;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: -0.5,
              ),
              children: const [
                TextSpan(text: 'LAUNDRY', style: TextStyle(color: Color(0xFF6D28D9))),
                TextSpan(text: 'LINK', style: TextStyle(color: Color(0xFF16A34A))),
              ],
            ),
          ),
        ],
      );
}