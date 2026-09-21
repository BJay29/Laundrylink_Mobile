import 'package:flutter/foundation.dart';

import '../main.dart' show supabase;
import '../models/customer.dart';
import 'api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Session state para sa currently logged-in customer.
///
/// UPDATED (Supabase Auth migration): MALAKING SIMPLIFICATION — hindi na
/// ito ang nag-a-asikaso ng token persistence mismo. Si Supabase Auth
/// SDK (supabase_flutter) na ang may sariling built-in na encrypted
/// session storage sa disk, kasama na ang automatic token refresh —
/// kaya ang dating sariling flutter_secure_storage logic dito
/// (setSession/restoreSession na nagsu-save/nagbabasa ng JSON) ay HINDI
/// NA KAILANGAN. Ang klase na ito ay nagiging simpleng "cache" na lang
/// ng CUSTOMER PROFILE object (yung data galing sa Aiven DB — full_name,
/// mobile_number, atbp. — na wala sa Supabase Auth mismo), hindi na ng
/// token.
///
/// Ang token mismo ay hinahanap na LIVE galing sa
/// `supabase.auth.currentSession?.accessToken` sa bawat kailangan ito
/// (see [authToken] getter sa ibaba) — laging up-to-date ito dahil
/// awtomatikong ine-refresh ni Supabase ang expiring tokens sa likod.
class CustomerSession extends ChangeNotifier {
  CustomerSession._internal() {
    // Nakikinig sa Supabase auth state changes (hal. kapag nag-expire
    // o na-revoke ang session sa ibang device) para awtomatikong
    // ma-clear ang naka-cache na customer profile, kahit hindi
    // dumaan sa sariling logout() method na ito.
    supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        _customer = null;
        notifyListeners();
      }
    });
  }

  static final CustomerSession instance = CustomerSession._internal();

  final ApiService _api = ApiService();

  Customer? _customer;

  Customer? get customer => _customer;

  /// Kinukuha nang live mula sa Supabase — hindi na naka-cache dito,
  /// para laging sigurado tayong hindi expired ang ginagamit na token.
  String? get authToken => supabase.auth.currentSession?.accessToken;

  bool get isLoggedIn => _customer != null && authToken != null;

  /// Tawagin ito sa SplashPage bago mag-decide papuntang Home o
  /// Welcome/Login. Awtomatiko nang na-restore ni Supabase ang sarili
  /// niyang session (kung meron) sa oras na tumakbo ang
  /// Supabase.initialize() sa main.dart — ang kailangan na lang nating
  /// gawin dito ay kunin ang CUSTOMER PROFILE (mula sa Aiven DB) gamit
  /// ang naibalik na session, kung meron.
  Future<void> restoreSession() async {
    final token = supabase.auth.currentSession?.accessToken;
    if (token == null) {
      _customer = null;
      notifyListeners();
      return;
    }

    try {
      final response = await _api.get('/customer/profile', token: token);
      _customer = Customer.fromJson(response);
    } on ApiException {
      // Puwedeng mangyari kung expired/invalid na pala ang session, o
      // hindi pa na-sync ang account (webhook race condition). Ligtas
      // na i-treat na lang bilang "hindi naka-login" sa halip na
      // i-crash ang app pag-launch.
      _customer = null;
    } finally {
      notifyListeners();
    }
  }

  /// Tawagin pagkatapos mag-login — inaasahan nang naka-set up na ang
  /// Supabase session bago ito tawagin (see AuthService.login()).
  void setSession({required Customer customer}) {
    _customer = customer;
    notifyListeners();
  }

  /// Tawagin pagkatapos mag-refresh ng profile data (hal. after
  /// pag-edit ng "Personal information" sa Settings).
  void updateCustomer(Customer customer) {
    _customer = customer;
    notifyListeners();
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
    _customer = null;
    notifyListeners();
  }
}