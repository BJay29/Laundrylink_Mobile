import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_layout.dart';
import 'verify_otp_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

/// UPDATED (bug fix) — pinalitan ang _TapScale para gumamit ng Listener
/// (raw pointer tracking lang, hindi tap-gesture recognizer) sa halip
/// na GestureDetector.onTap. Dating pattern: outer GestureDetector may
/// onTap, inner FilledButton naka onPressed:null — minsan nagkaka-
/// conflict sa gesture arena kaya "di na-cclick" ang button. Ngayon,
/// ang FilledButton mismo ang may totoong onPressed; ang Listener ay
/// para lang sa visual "press down" scale effect.
class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _loading = false;

  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _entrance.forward();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _mobile.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _message(String text, {bool success = false}) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: success ? context.colors.success : context.colors.error,
          content: Text(text),
        ),
      );

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      _message('Please complete all required fields.');
      return;
    }
    setState(() => _loading = true);
    try {
      final registeredEmail = _email.text.trim();
      await AuthService().signUp(
        fullName: _name.text.trim(),
        email: registeredEmail,
        password: _password.text,
        mobileNumber: '+63${_mobile.text.trim()}',
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          _fadeSlideRoute(VerifyOtpPage(email: registeredEmail)),
        );
      }
    } catch (error) {
      if (mounted) _message('Unable to create your account. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
          offset: Offset(0, (1 - fade.value) * 14),
          child: child,
        ),
      ),
      child: child,
    );
  }

  Widget _animatedVisibilityIcon(bool hidden) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: RotationTransition(turns: animation, child: child),
        ),
        child: Icon(
          hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          key: ValueKey(hidden),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AuthLayout(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _staggered(
              start: 0.0,
              end: 0.4,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.person_add_alt_1_rounded, color: colors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Create your account',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _staggered(
              start: 0.03,
              end: 0.43,
              child: Text(
                'Get dependable laundry care in one place.',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            const SizedBox(height: 28),
            _staggered(
              start: 0.1,
              end: 0.5,
              child: AppTextField(
                controller: _name,
                label: 'Full name *',
                icon: Icons.person_outline,
                validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null,
              ),
            ),
            const SizedBox(height: 16),
            _staggered(
              start: 0.16,
              end: 0.56,
              child: AppTextField(
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
            ),
            const SizedBox(height: 16),
            _staggered(
              start: 0.22,
              end: 0.62,
              child: AppTextField(
                controller: _mobile,
                label: 'Mobile number *',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.number,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                prefixText: Text(
                  '+63 ',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Mobile number is required'
                    : v.length != 10
                        ? 'Enter a valid 10-digit mobile number'
                        : !v.startsWith('9')
                            ? 'Mobile number should start with 9'
                            : null,
              ),
            ),
            const SizedBox(height: 16),
            _staggered(
              start: 0.28,
              end: 0.68,
              child: AppTextField(
                controller: _password,
                label: 'Password *',
                icon: Icons.lock_outline,
                obscureText: _hidePassword,
                suffix: IconButton(
                  icon: _animatedVisibilityIcon(_hidePassword),
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                ),
                validator: (v) => v == null || v.isEmpty
                    ? 'Password is required'
                    : v.length < 6
                        ? 'Password must be at least 6 characters'
                        : null,
              ),
            ),
            const SizedBox(height: 16),
            _staggered(
              start: 0.34,
              end: 0.74,
              child: AppTextField(
                controller: _confirmPassword,
                label: 'Confirm password *',
                icon: Icons.lock_outline,
                obscureText: _hideConfirmPassword,
                suffix: IconButton(
                  icon: _animatedVisibilityIcon(_hideConfirmPassword),
                  onPressed: () => setState(() => _hideConfirmPassword = !_hideConfirmPassword),
                ),
                validator: (v) => v == null || v.isEmpty
                    ? 'Please confirm your password'
                    : v != _password.text
                        ? 'Passwords do not match'
                        : null,
              ),
            ),
            const SizedBox(height: 24),
            _staggered(
              start: 0.45,
              end: 0.9,
              child: _TapScale(
                enabled: !_loading,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withOpacity(_loading ? 0 : 0.30),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    // FIX: totoong onPressed na dito mismo (_register),
                    // hindi na empty closure na naka-depend sa outer
                    // GestureDetector.
                    onPressed: _loading ? null : _register,
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
                      child: _loading
                          ? const SizedBox(
                              key: ValueKey('loading'),
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                            )
                          : const Text('Create account', key: ValueKey('label'), style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ),
            _staggered(
              start: 0.55,
              end: 1.0,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Already have an account? Sign in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// FIX: Listener na lang (raw pointer events) sa halip na GestureDetector
/// para sa "press down" visual scale — hindi na siya lumalahok sa tap
/// gesture arena, kaya walang conflict sa totoong onPressed ng button
/// sa loob. Wala nang onTap parameter dito — ang totoong tap ay hawak
/// na ng FilledButton/IconButton mismo.
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