import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show supabase;
import '../models/customer.dart';
import 'api_service.dart';
import 'customer_session.dart';

/// Authentication para sa LaundryLink customer (mobile app) —
/// GUMAGAMIT NA NG SUPABASE AUTH SDK, hindi na direktang HTTP calls
/// papunta sa sariling FastAPI backend.
class AuthService {
  AuthService({ApiService? api}) : _api = api ?? ApiService();
  final ApiService _api;

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    required String mobileNumber,
  }) async {
    await supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'role': 'customer',
        'full_name': fullName,
        'mobile_number': mobileNumber,
      },
    );
  }

  Future<void> verifyOtp({
    required String email,
    required String code,
  }) async {
    await supabase.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.email,
    );
  }

  Future<void> resendOtp(String email) async {
    await supabase.auth.resend(
      type: OtpType.signup,
      email: email,
    );
  }

  Future<Customer> login(String email, String password) async {
    final authResponse = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final accessToken = authResponse.session?.accessToken;
    if (accessToken == null) {
      throw const ApiException('Login succeeded but no session was returned.');
    }

    final response = await _api.get('/customer/profile', token: accessToken);
    final customer = Customer.fromJson(response);

    CustomerSession.instance.setSession(customer: customer);
    return customer;
  }

  /// HAKBANG 1 ng forgot password: nagpapadala ng email na may
  /// 6-digit code (kailangang naka-set ang "Reset Password" email
  /// template sa Supabase para ipakita ang {{ .Token }}).
  Future<void> forgotPassword(String email) async {
    await supabase.auth.resetPasswordForEmail(email);
  }

  /// HAKBANG 2: bine-verify ang code. Kapag tama, may recovery
  /// session na ang user (kailangan ito para makapag-update ng password).
  Future<void> verifyRecoveryOtp({
    required String email,
    required String code,
  }) async {
    await supabase.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.recovery,
    );
  }

  /// HAKBANG 3: nagse-set ng bagong password gamit ang recovery
  /// session, tapos sine-sign out para kailangang mag-login ulit
  /// gamit ang bagong password.
  Future<void> setNewPassword(String newPassword) async {
    await supabase.auth.updateUser(UserAttributes(password: newPassword));
    await supabase.auth.signOut();
  }

  Future<void> logout() async {
    await CustomerSession.instance.logout();
  }
}