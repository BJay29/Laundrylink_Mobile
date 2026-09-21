import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_layout.dart';
import 'main_nav_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.prefilledEmail});
  final String? prefilledEmail;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.prefilledEmail ?? '');
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
      // UPDATED — kinukuha na direkta ang Customer mula sa return value
      // ng login(), sa halip na mag-force-unwrap ng
      // CustomerSession.instance.customer! — mas ligtas dahil sigurado
      // tayong hindi null 'to kung umabot dito nang walang exception.
      final customer = await AuthService().login(_email.text.trim(), _password.text);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => MainNavPage(customer: customer)),
          (route) => false,
        );
      }
    } catch (error) {
      if (mounted) _message('Unable to sign in. Please check your credentials and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (_email.text.trim().isEmpty || !_email.text.contains('@')) {
      _message('Enter a valid email address first.');
      return;
    }
    try {
      await AuthService().forgotPassword(_email.text.trim());
      if (mounted) _message('Password reset instructions were sent.', success: true);
    } catch (_) {
      if (mounted) _message('Could not send reset instructions.');
    }
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
            Text(
              'Welcome back',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to manage your laundry with ease.',
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 28),
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
            AppTextField(
              controller: _password,
              label: 'Password *',
              icon: Icons.lock_outline,
              obscureText: _hidePassword,
              suffix: IconButton(
                icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _hidePassword = !_hidePassword),
              ),
              validator: (v) => v == null || v.isEmpty
                  ? 'Password is required'
                  : v.length < 6
                      ? 'Password must be at least 6 characters'
                      : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _forgotPassword, child: const Text('Forgot password?')),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loading ? null : _login,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Sign in'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account?"),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  ),
                  child: const Text('Register here'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}