import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show supabase;
import '../models/customer.dart';
import 'api_service.dart';
import 'customer_session.dart';

/// Customer (mobile app) profile endpoints — "Personal information" edit
/// sa Settings. Ang "Change password" ay hindi na dito tumatawag sa
/// sariling backend (see changePassword() sa ibaba) — Supabase Auth SDK
/// na direkta ang gumagawa nito.
class CustomerService {
  CustomerService({ApiService? api}) : _api = api ?? ApiService();
  final ApiService _api;

  /// Updates the logged-in customer's full_name and/or mobile_number.
  /// Walang binago dito — tugma pa rin ito sa bagong PATCH
  /// /customer/profile route sa backend.
  Future<Customer> updateProfile({
    String? fullName,
    String? mobileNumber,
  }) async {
    final token = CustomerSession.instance.authToken;
    if (token == null) {
      throw const ApiException('You must be logged in to update your profile.', statusCode: 401);
    }

    final body = <String, dynamic>{
      if (fullName != null && fullName.trim().isNotEmpty) 'full_name': fullName.trim(),
      if (mobileNumber != null && mobileNumber.trim().isNotEmpty) 'mobile_number': mobileNumber.trim(),
    };

    final data = await _api.patch('/customer/profile', body, token: token);
    final updated = Customer.fromJson(data);

    // UPDATED — CustomerSession na ngayon ay ChangeNotifier-based at
    // ang setSession() nito ay hindi na tumatanggap ng 'token'
    // (kinukuha na 'yun live mula kay Supabase). Ginamit ang
    // updateCustomer() dito dahil parehas lang naman ang layunin —
    // i-refresh ang naka-cache na Customer object nang hindi
    // ginagalaw ang session/token.
    CustomerSession.instance.updateCustomer(updated);

    return updated;
  }

  /// UPDATED (Supabase Auth migration): buong pinalitan — hindi na ito
  /// tumatawag sa sariling backend (PUT /customer/password ay tinanggal
  /// na, walang FastAPI route na gumagawa nito ngayon). Si Supabase
  /// Auth SDK na ang direktang humahawak ng password storage/updates.
  ///
  /// Bago mag-updateUser(), muna nating "re-verify" ang current
  /// password sa pamamagitan ng signInWithPassword() gamit ang email
  /// ng kasalukuyang naka-login na customer + ang ibinigay na
  /// oldPassword — kung mali ang oldPassword, mag-tha-throw ito ng
  /// AuthException dito mismo bago pa man ma-attempt ang aktwal na
  /// pag-update, kaya nananatiling meaningful ang "Current password"
  /// field sa UI (hindi lang basta ignored).
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final customer = CustomerSession.instance.customer;
    if (customer == null) {
      throw const ApiException('You must be logged in to change your password.', statusCode: 401);
    }

    try {
      // Re-verify current password.
      await supabase.auth.signInWithPassword(
        email: customer.email ?? '',
        password: oldPassword,
      );

      // Update to the new password.
      await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      // Normalize papunta sa ApiException para hindi na kailangang
      // baguhin ang error-handling sa change_password_page.dart
      // (na naka-catch pa rin ng ApiException).
      throw ApiException(e.message);
    }
  }
}