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

  Future<void> forgotPassword(String email) async {
    await supabase.auth.resetPasswordForEmail(email);
  }

  Future<void> logout() async {
    await CustomerSession.instance.logout();
  }
}