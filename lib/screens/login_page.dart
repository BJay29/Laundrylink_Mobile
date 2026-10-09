import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_layout.dart';
import 'forgot_password_page.dart';
import 'main_nav_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.prefilledEmail});
  final String? prefilledEmail;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.prefilledEmail ?? '');
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _loading = false;

  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _entrance.forward();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _message(String text, {bool success = false}) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: success ? context.colors.success : context.colors.error,
          content: Text(text),
        ),
      );

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      _message('Please fill out all required fields.');
      return;
    }
    setState(() => _loading = true);
    try {
      final customer = await AuthService().login(_email.text.trim(), _password.text);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          _fadeSlideRoute(MainNavPage(customer: customer)),
          (route) => false,
        );
      }
    } catch (error) {
      if (mounted) _message('Unable to sign in. Please check your credentials and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Bubuksan ang Forgot Password flow (email -> code -> bagong password).
  void _forgotPassword() {
    Navigator.push(
      context,
      _fadeSlideRoute(ForgotPasswordPage(prefilledEmail: _email.text.trim())),
    );
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
              end: 0.5,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.local_laundry_service_rounded, color: colors.primary, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Welcome back',
                      style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _staggered(
              start: 0.05,
              end: 0.55,
              child: Text(
                'Sign in to manage your laundry with ease.',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ),
            const SizedBox(height: 20),
            _staggered(
              start: 0.15,
              end: 0.65,
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
            const SizedBox(height: 12),
            _staggered(
              start: 0.25,
              end: 0.75,
              // Walang max-length dito sa login, sinadya (para sa lumang account).
              child: AppTextField(
                controller: _password,
                label: 'Password *',
                icon: Icons.lock_outline,
                obscureText: _hidePassword,
                suffix: IconButton(
                  iconSize: 20,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: RotationTransition(turns: animation, child: child),
                    ),
                    child: Icon(
                      _hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      key: ValueKey(_hidePassword),
                    ),
                  ),
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Password is required' : null,
              ),
            ),
            _staggered(
              start: 0.3,
              end: 0.8,
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  onPressed: _forgotPassword,
                  child: const Text('Forgot password?'),
                ),
              ),
            ),
            const SizedBox(height: 4),
            _staggered(
              start: 0.4,
              end: 0.9,
              child: _TapScale(
                enabled: !_loading,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: _loading ? 0 : 0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    onPressed: _loading ? null : _login,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: colors.primary.withValues(alpha: 0.7),
                      disabledForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _loading
                          ? const SizedBox(
                              key: ValueKey('loading'),
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                            )
                          : const Text(
                              'Sign in',
                              key: ValueKey('label'),
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _staggered(
              start: 0.5,
              end: 1.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?", style: TextStyle(fontSize: 13)),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      _fadeSlideRoute(const RegisterPage()),
                    ),
                    child: const Text('Register here'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Listener-based "press down" scale; ang totoong tap ay hawak ng FilledButton.
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