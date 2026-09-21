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
class VerifyOtpPage extends StatefulWidget {
  const VerifyOtpPage({super.key, required this.email});
  final String email;

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  static const _resendCooldownSeconds = 60;

  final _codeController = TextEditingController();
  bool _verifying = false;
  bool _resending = false;
  bool _syncing = false;

  // NEW — countdown state para sa "Resend" cooldown. Nagsisimula agad
  // sa 60s pagbukas ng page (dahil kaka-signUp() lang, may fresh code
  // na naipadala na) — hindi lang pagkatapos ng unang resend tap.
  int _resendSecondsLeft = _resendCooldownSeconds;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _resendTimer?.cancel();
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
          MaterialPageRoute(builder: (_) => MainNavPage(customer: customer!)),
          (route) => false,
        );
      } else {
        _message('Verified! Please sign in — this may take a moment to finish syncing.', success: true);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => LoginPage(prefilledEmail: widget.email)),
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
        // NEW — i-restart ang 60s cooldown pagkatapos ng successful resend.
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

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: colors.shadowStrong, blurRadius: 26, offset: const Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: IllustratedIcon(icon: Icons.mail_outline_rounded, size: 88)),
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
                    FilledButton(
                      onPressed: busy ? null : _verify,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: busy
                          ? Text(_syncing ? 'Finishing setup…' : '', style: const TextStyle(color: Colors.white))
                          : const Text('Verify account'),
                    ),
                    if (busy) ...[
                      const SizedBox(height: 12),
                      const Center(child: CircularProgressIndicator()),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Didn't receive a code?", style: TextStyle(color: colors.textSecondary)),
                        TextButton(
                          onPressed: canResend ? _resend : null,
                          child: _resending
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(
                                  _resendSecondsLeft > 0 ? 'Resend in ${_resendSecondsLeft}s' : 'Resend',
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
    );
  }
}