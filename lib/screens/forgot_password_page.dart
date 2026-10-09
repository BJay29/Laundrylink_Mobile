import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_layout.dart';
import 'login_page.dart';

/// Password rule — dapat kapareho ng register_page.dart.
const int _kPasswordMin = 8;
const int _kPasswordMax = 12;

enum _Step { email, code, newPassword }

/// Forgot Password (OTP flow):
///   1. email  -> AuthService.forgotPassword()
///   2. code   -> AuthService.verifyRecoveryOtp()
///   3. new pw -> AuthService.setNewPassword() -> balik sa Login
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.prefilledEmail});
  final String? prefilledEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static const _resendCooldownSeconds = 60;

  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.prefilledEmail ?? '');
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  _Step _step = _Step.email;
  bool _loading = false;
  bool _hidePassword = true;
  bool _hideConfirm = true;

  int _resendSecondsLeft = 0;
  Timer? _resendTimer;

  bool get _lengthOk =>
      _password.text.length >= _kPasswordMin && _password.text.length <= _kPasswordMax;

  @override
  void initState() {
    super.initState();
    _password.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _message(String text, {bool success = false}) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: success ? context.colors.success : context.colors.error,
          content: Text(text),
        ),
      );

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

  // ── Hakbang 1: ipadala ang code ───────────────────────────────────
  Future<void> _sendCode({bool isResend = false}) async {
    if (!isResend && !(_emailFormKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await AuthService().forgotPassword(_email.text.trim());
      if (!mounted) return;
      _startResendCooldown();
      setState(() => _step = _Step.code);
      _message('If that email has an account, a code was sent.', success: true);
    } catch (_) {
      if (mounted) _message('Could not send the code. Please try again in a moment.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Hakbang 2: i-verify ang code ──────────────────────────────────
  Future<void> _verifyCode() async {
    final code = _code.text.trim();
    if (code.length < 6) {
      _message('Enter the code sent to your email.');
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService().verifyRecoveryOtp(email: _email.text.trim(), code: code);
      if (mounted) setState(() => _step = _Step.newPassword);
    } catch (_) {
      if (mounted) _message('Invalid or expired code. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Hakbang 3: bagong password ────────────────────────────────────
  Future<void> _saveNewPassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await AuthService().setNewPassword(_password.text);
      if (!mounted) return;
      _message('Password updated. Please sign in.', success: true);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginPage(prefilledEmail: _email.text.trim())),
        (route) => false,
      );
    } catch (_) {
      if (mounted) _message('Could not update your password. Please start again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _primaryButton({required String label, required VoidCallback onPressed}) {
    final colors = context.colors;
    return FilledButton(
      onPressed: _loading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: colors.primary.withValues(alpha: 0.7),
        disabledForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
    );
  }

  Widget _header(IconData icon, String title, String subtitle) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colors.primary, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: colors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.4)),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── UI: hakbang 1 ─────────────────────────────────────────────────
  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(
            Icons.lock_reset_rounded,
            'Forgot password?',
            "Enter your account email and we'll send you a 6-digit code.",
          ),
          AppTextField(
            controller: _email,
            label: 'Email address *',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Email address is required'
                : !v.contains('@')
                    ? 'Enter a valid email address'
                    : null,
          ),
          const SizedBox(height: 16),
          _primaryButton(label: 'Send code', onPressed: _sendCode),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    );
  }

  // ── UI: hakbang 2 ─────────────────────────────────────────────────
  Widget _buildCodeStep() {
    final colors = context.colors;
    final canResend = !_loading && _resendSecondsLeft == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          Icons.mark_email_read_outlined,
          'Enter the code',
          'We sent a code to\n${_email.text.trim()}',
        ),
        TextField(
          controller: _code,
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
        const SizedBox(height: 16),
        _primaryButton(label: 'Verify code', onPressed: _verifyCode),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Didn't receive a code?", style: TextStyle(fontSize: 13, color: colors.textSecondary)),
            TextButton(
              onPressed: canResend ? () => _sendCode(isResend: true) : null,
              child: Text(_resendSecondsLeft > 0 ? 'Resend in ${_resendSecondsLeft}s' : 'Resend'),
            ),
          ],
        ),
        TextButton(
          onPressed: _loading
              ? null
              : () => setState(() {
                    _code.clear();
                    _step = _Step.email;
                  }),
          child: const Text('Use a different email'),
        ),
      ],
    );
  }

  // ── UI: hakbang 3 ─────────────────────────────────────────────────
  Widget _animatedVisibilityIcon(bool hidden) => Icon(
        hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        key: ValueKey(hidden),
      );

  Widget _buildNewPasswordStep() {
    final colors = context.colors;
    final empty = _password.text.isEmpty;
    final ruleColor = empty ? colors.textMuted : (_lengthOk ? colors.success : colors.error);

    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(
            Icons.lock_outline_rounded,
            'Set new password',
            'Choose a new password for your account.',
          ),
          AppTextField(
            controller: _password,
            label: 'New password *',
            icon: Icons.lock_outline,
            obscureText: _hidePassword,
            inputFormatters: [LengthLimitingTextInputFormatter(_kPasswordMax)],
            suffix: IconButton(
              iconSize: 20,
              icon: _animatedVisibilityIcon(_hidePassword),
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < _kPasswordMin) return 'Password must be at least $_kPasswordMin characters';
              if (v.length > _kPasswordMax) return 'Password must be at most $_kPasswordMax characters';
              return null;
            },
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Row(
              children: [
                Icon(_lengthOk ? Icons.check_circle_rounded : Icons.circle_outlined, size: 14, color: ruleColor),
                const SizedBox(width: 6),
                Text(
                  '$_kPasswordMin–$_kPasswordMax characters',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ruleColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          AppTextField(
            controller: _confirmPassword,
            label: 'Confirm new password *',
            icon: Icons.lock_outline,
            obscureText: _hideConfirm,
            inputFormatters: [LengthLimitingTextInputFormatter(_kPasswordMax)],
            suffix: IconButton(
              iconSize: 20,
              icon: _animatedVisibilityIcon(_hideConfirm),
              onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
            ),
            validator: (v) => v == null || v.isEmpty
                ? 'Please confirm your password'
                : v != _password.text
                    ? 'Passwords do not match'
                    : null,
          ),
          const SizedBox(height: 16),
          _primaryButton(label: 'Update password', onPressed: _saveNewPassword),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    switch (_step) {
      case _Step.email:
        content = _buildEmailStep();
        break;
      case _Step.code:
        content = _buildCodeStep();
        break;
      case _Step.newPassword:
        content = _buildNewPasswordStep();
        break;
    }

    return AuthLayout(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(key: ValueKey(_step), child: content),
      ),
    );
  }
}