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

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _mobile.dispose();
    _password.dispose();
    _confirmPassword.dispose();
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
      // UPDATED — signUp() na sa halip na register(). Walang ibinabalik
      // na Customer dito (hindi pa na-verify/na-sync ang account) —
      // ang susunod na hakbang ay ang OTP verification screen, hindi na
      // direktang LoginPage.
      await AuthService().signUp(
        fullName: _name.text.trim(),
        email: registeredEmail,
        password: _password.text,
        mobileNumber: '+63${_mobile.text.trim()}',
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => VerifyOtpPage(email: registeredEmail)),
        );
      }
    } catch (error) {
      if (mounted) _message('Unable to create your account. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
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
              'Create your account',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Get dependable laundry care in one place.',
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 28),
            AppTextField(
              controller: _name,
              label: 'Full name *',
              icon: Icons.person_outline,
              validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null,
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            AppTextField(
              controller: _confirmPassword,
              label: 'Confirm password *',
              icon: Icons.lock_outline,
              obscureText: _hideConfirmPassword,
              suffix: IconButton(
                icon: Icon(_hideConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _hideConfirmPassword = !_hideConfirmPassword),
              ),
              validator: (v) => v == null || v.isEmpty
                  ? 'Please confirm your password'
                  : v != _password.text
                      ? 'Passwords do not match'
                      : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _register,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Create account'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Already have an account? Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}