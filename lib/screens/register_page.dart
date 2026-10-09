import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_layout.dart';
import 'verify_otp_page.dart';

/// Password rule (palitan lang dito kung gusto mong baguhin).
/// Sa SIGNUP lang ito, hindi sa login, para hindi ma-lock out ang
/// mga lumang account na mas mahaba ang password.
const int kPasswordMin = 8;
const int kPasswordMax = 12;

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

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

  bool get _lengthOk =>
      _password.text.length >= kPasswordMin && _password.text.length <= kPasswordMax;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _entrance.forward();
    // Para mag-update ang live checklist habang nagta-type.
    _password.addListener(() {
      if (mounted) setState(() {});
    });
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

  /// Live checklist: abo kung walang laman, berde kung pasado, pula kung hindi.
  Widget _passwordRules(AppColors colors) {
    final empty = _password.text.isEmpty;
    final ok = _lengthOk;
    final color = empty ? colors.textMuted : (ok ? colors.success : colors.error);
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 6),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.circle_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$kPasswordMin–$kPasswordMax characters',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
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
              end: 0.4,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.person_add_alt_1_rounded, color: colors.primary, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Create your account',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _staggered(
              start: 0.03,
              end: 0.43,
              child: Text(
                'Get dependable laundry care in one place.',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ),
            const SizedBox(height: 18),
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
            const SizedBox(height: 11),
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
            const SizedBox(height: 11),
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
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary),
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
            const SizedBox(height: 11),
            _staggered(
              start: 0.28,
              end: 0.68,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    controller: _password,
                    label: 'Password *',
                    icon: Icons.lock_outline,
                    obscureText: _hidePassword,
                    // Hindi na makakapag-type ng lampas 12.
                    inputFormatters: [LengthLimitingTextInputFormatter(kPasswordMax)],
                    suffix: IconButton(
                      iconSize: 20,
                      icon: _animatedVisibilityIcon(_hidePassword),
                      onPressed: () => setState(() => _hidePassword = !_hidePassword),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.length < kPasswordMin) return 'Password must be at least $kPasswordMin characters';
                      if (v.length > kPasswordMax) return 'Password must be at most $kPasswordMax characters';
                      return null;
                    },
                  ),
                  _passwordRules(colors),
                ],
              ),
            ),
            const SizedBox(height: 11),
            _staggered(
              start: 0.34,
              end: 0.74,
              child: AppTextField(
                controller: _confirmPassword,
                label: 'Confirm password *',
                icon: Icons.lock_outline,
                obscureText: _hideConfirmPassword,
                inputFormatters: [LengthLimitingTextInputFormatter(kPasswordMax)],
                suffix: IconButton(
                  iconSize: 20,
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
            const SizedBox(height: 16),
            _staggered(
              start: 0.45,
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
                    onPressed: _loading ? null : _register,
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
                              'Create account',
                              key: ValueKey('label'),
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            _staggered(
              start: 0.55,
              end: 1.0,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 13),
                ),
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