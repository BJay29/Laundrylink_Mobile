import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/customer.dart';
import '../services/auth_service.dart';
import '../services/customer_session.dart';
import '../theme/app_colors.dart';
import '../widgets/illustrated_icon.dart';
import 'login_page.dart';
import 'main_nav_page.dart';

/// Verify-OTP screen — ipinapakita pagkatapos mag-signUp(). Kinukuha
/// ang 6-digit code na ipinadala ni Supabase sa email, tapos
/// kino-confirm via AuthService().verifyOtp().
///
/// Pagkatapos ng successful verify, may posibleng maliit na delay bago
/// makita ang naka-sync na Customer profile sa Aiven DB (kailangan pang
/// mag-fire ang Database Webhook at tapusin ang sync) — kaya may
/// retry loop dito bago tuluyang mag-navigate.
///
/// UPDATED (bug fix) — pinalitan ang _TapScale para gumamit ng Listener
/// (raw pointer lang, hindi tap-gesture recognizer) sa halip na
/// GestureDetector.onTap. Dating pattern: outer GestureDetector may
/// onTap: _verify, habang inner FilledButton naka onPressed: () {}
/// (walang laman) — nagkaka-conflict sa gesture arena kaya minsan
/// hindi na-cclick ang button. Ngayon, ang FilledButton mismo ang may
/// totoong onPressed: _verify; ang Listener ay para lang sa visual
/// "press down" scale effect. Walang binago sa OTP/session logic.
class VerifyOtpPage extends StatefulWidget {
  const VerifyOtpPage({super.key, required this.email});
  final String email;

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> with TickerProviderStateMixin {
  static const _resendCooldownSeconds = 60;

  final _codeController = TextEditingController();
  bool _verifying = false;
  bool _resending = false;
  bool _syncing = false;

  // Countdown state para sa "Resend" cooldown. Nagsisimula agad
  // sa 60s pagbukas ng page (dahil kaka-signUp() lang, may fresh code
  // na naipadala na) — hindi lang pagkatapos ng unang resend tap.
  int _resendSecondsLeft = _resendCooldownSeconds;
  Timer? _resendTimer;

  late final AnimationController _entrance;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();

    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _entrance.forward();

    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _resendTimer?.cancel();
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    setState(() => _resendSecondsLeft = _resendCooldownSeconds);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _resendSecondsLeft = 0);
      } else {
        setState(() => _resendSecondsLeft--);
      }
    });
  }

  void _message(String text, {bool success = false}) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: success ? context.colors.success : context.colors.error,
          content: Text(text),
        ),
      );

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      _message('Enter the code sent to your email.');
      return;
    }

    setState(() => _verifying = true);
    try {
      await AuthService().verifyOtp(email: widget.email, code: code);

      if (!mounted) return;
      setState(() {
        _verifying = false;
        _syncing = true;
      });

      Customer? customer;
      for (var attempt = 0; attempt < 4 && customer == null; attempt++) {
        if (attempt > 0) await Future.delayed(const Duration(milliseconds: 1500));
        await CustomerSession.instance.restoreSession();
        customer = CustomerSession.instance.customer;
      }

      if (!mounted) return;
      setState(() => _syncing = false);

      if (customer != null) {
        _message('Email verified!', success: true);
        Navigator.of(context).pushAndRemoveUntil(
          _fadeSlideRoute(MainNavPage(customer: customer!)),
          (route) => false,
        );
      } else {
        _message('Verified! Please sign in — this may take a moment to finish syncing.', success: true);
        Navigator.of(context).pushAndRemoveUntil(
          _fadeSlideRoute(LoginPage(prefilledEmail: widget.email)),
          (route) => false,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _verifying = false;
          _syncing = false;
        });
        _message('Invalid or expired code. Please try again.');
      }
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await AuthService().resendOtp(widget.email);
      if (mounted) {
        _message('A new code was sent to your email.', success: true);
        // i-restart ang 60s cooldown pagkatapos ng successful resend.
        _startResendCooldown();
      }
    } catch (_) {
      if (mounted) _message('Unable to resend the code. Please try again.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final busy = _verifying || _syncing;
    final canResend = !_resending && !busy && _resendSecondsLeft == 0;

    final entranceCurve = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);

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
        child: Stack(
          children: [
            Positioned(
              top: -60,
              left: -50,
              child: _Blob(color: colors.primary.withOpacity(0.10), size: 200),
            ),
            Positioned(
              bottom: -80,
              right: -60,
              child: _Blob(color: colors.primary.withOpacity(0.08), size: 240),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: FadeTransition(
                      opacity: entranceCurve,
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(entranceCurve),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: colors.shadowStrong, blurRadius: 30, offset: const Offset(0, 10)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: AnimatedBuilder(
                                  animation: _pulse,
                                  builder: (context, child) {
                                    final scale = 1.0 + (_pulse.value * 0.06);
                                    final glow = 0.15 + (_pulse.value * 0.15);
                                    return Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: colors.primary.withOpacity(glow),
                                            blurRadius: 28,
                                            spreadRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Transform.scale(scale: scale, child: child),
                                    );
                                  },
                                  child: IllustratedIcon(icon: Icons.mail_outline_rounded, size: 88),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Verify your email',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: colors.textPrimary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'We sent a code to\n${widget.email}',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.5),
                              ),
                              const SizedBox(height: 28),
                              TextField(
                                controller: _codeController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 8,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 10, color: colors.textPrimary),
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: '------',
                                  hintStyle: TextStyle(letterSpacing: 10, color: colors.textMuted),
                                  filled: true,
                                  fillColor: colors.inputFill,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: colors.inputBorder)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: colors.inputBorder)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: colors.primary, width: 2)),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _TapScale(
                                enabled: !busy,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colors.primary.withOpacity(busy ? 0 : 0.30),
                                        blurRadius: 16,
                                        offset: const Offset(0, 7),
                                      ),
                                    ],
                                  ),
                                  child: FilledButton(
                                    // FIX: totoong onPressed dito mismo
                                    // (_verify), hindi na empty closure.
                                    onPressed: busy ? null : _verify,
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(52),
                                      backgroundColor: colors.primary,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: colors.primary.withOpacity(0.7),
                                      disabledForegroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      child: busy
                                          ? Row(
                                              key: const ValueKey('busy'),
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(_syncing ? 'Finishing setup…' : 'Verifying…', style: const TextStyle(color: Colors.white)),
                                              ],
                                            )
                                          : const Text('Verify account', key: ValueKey('label'), style: TextStyle(fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("Didn't receive a code?", style: TextStyle(color: colors.textSecondary)),
                                  TextButton(
                                    onPressed: canResend ? _resend : null,
                                    child: _resending
                                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                        : AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 200),
                                            child: Text(
                                              _resendSecondsLeft > 0 ? 'Resend in ${_resendSecondsLeft}s' : 'Resend',
                                              key: ValueKey(_resendSecondsLeft > 0),
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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

/// FIX: Listener na lang (raw pointer, walang tap-arena participation)
/// para sa "press down" visual scale. Ang totoong onPressed ay nasa
/// FilledButton mismo sa loob ng child — kaya wala nang conflict sa
/// gesture arena.
class _TapScale extends StatefulWidget {
  const _TapScale({required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
        onPointerUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
        onPointerCancel: widget.enabled ? (_) => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

/// fade + slight upward-slide na page transition.
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