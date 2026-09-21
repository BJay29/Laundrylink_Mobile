import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Backend client for the LaundryLink FastAPI server (deployed on Render).
class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String baseUrl = 'https://laundrylink-backend-8p1l.onrender.com';

  /// Timeout applied to every request. Render free-tier instances can take
  /// a while to spin up from a cold start, so this is generous on purpose —
  /// better a slow success than a premature "failed" toast.
  static const Duration _timeout = Duration(seconds: 30);

  /// Builds the shared JSON headers, optionally including the Bearer token
  /// for authenticated endpoints (e.g. POST /customer/bookings). Pass the
  /// customer's JWT (from CustomerAuthService / wherever the session is
  /// stored) as [token]; leave it null for public endpoints (GET /shops/,
  /// login, register, atbp.).
  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final response = await _send(
      () => _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _headers(token),
            body: jsonEncode(body),
          )
          .timeout(_timeout),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> get(String path, {String? token}) async {
    final response = await _send(
      () => _client
          .get(Uri.parse('$baseUrl$path'), headers: _headers(token))
          .timeout(_timeout),
    );
    return _decodeObject(response);
  }

  /// Same as [get], pero para sa mga endpoint na nagbabalik ng JSON ARRAY
  /// sa halip na isang object — hal. GET /shops/ na nagbabalik ng listahan
  /// ng shops. Hiwalay na method dahil iba ang decode shape (List vs Map).
  Future<List<dynamic>> getList(String path, {String? token}) async {
    final response = await _send(
      () => _client
          .get(Uri.parse('$baseUrl$path'), headers: _headers(token))
          .timeout(_timeout),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _errorFromResponse(response);
    }

    return response.body.isEmpty
        ? <dynamic>[]
        : jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final response = await _send(
      () => _client
          .patch(
            Uri.parse('$baseUrl$path'),
            headers: _headers(token),
            body: jsonEncode(body),
          )
          .timeout(_timeout),
    );
    return _decodeObject(response);
  }

  /// NEW — kailangan ito ng PUT /customer/password (Change password
  /// feature, via CustomerService.changePassword()). Same shape as
  /// [patch]/[post]: body naka-JSON-encode, may Bearer token support.
  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final response = await _send(
      () => _client
          .put(
            Uri.parse('$baseUrl$path'),
            headers: _headers(token),
            body: jsonEncode(body),
          )
          .timeout(_timeout),
    );
    return _decodeObject(response);
  }

  /// NEW — kailangan ito ng DELETE /addresses/{id} (Saved Addresses
  /// feature). Same shape/error-handling pattern as [patch]/[post] —
  /// walang body ang DELETE dito dahil ang address_id ay nasa PATH na
  /// (RESTful convention, tugma sa backend's @router.delete("/{id}")).
  Future<Map<String, dynamic>> delete(String path, {String? token}) async {
    final response = await _send(
      () => _client
          .delete(Uri.parse('$baseUrl$path'), headers: _headers(token))
          .timeout(_timeout),
    );
    return _decodeObject(response);
  }

  /// Wraps every network call so raw client-level failures (no internet,
  /// DNS failure, timeout, malformed JSON) surface as a consistent
  /// ApiException instead of leaking dart:io/http exception types into the
  /// UI layer — the UI should only ever have to catch ApiException.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on TimeoutException {
      throw const ApiException('The request took too long. Please check your connection and try again.');
    } on SocketException {
      throw const ApiException('No internet connection. Please check your network and try again.');
    } on FormatException {
      throw const ApiException('Received an unexpected response from the server.');
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}');
    }
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _errorFromResponse(response);
    }
    return response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Normalizes a non-2xx response into an ApiException, carrying the
  /// statusCode along so the UI can special-case things like 401
  /// (session expired → send back to login) or 400 (validation / business
  /// rule errors, e.g. "This shop is currently closed...") differently.
  ApiException _errorFromResponse(http.Response response) {
    Map<String, dynamic> data;
    try {
      data = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      data = <String, dynamic>{};
    }

    // FastAPI validation errors (422) return `detail` as a LIST of
    // { type, loc, msg, input } objects, not a plain string. Normalize
    // that shape here too, same reasoning as the web app's
    // formatErrorDetail() — otherwise this throws a type error trying to
    // use a List where a String is expected.
    final rawDetail = data['detail'];
    String message;
    if (rawDetail is String) {
      message = rawDetail;
    } else if (rawDetail is List) {
      message = rawDetail
          .map((e) {
            if (e is String) return e;
            if (e is Map) {
              final loc = e['loc'];
              final field = (loc is List && loc.isNotEmpty) ? loc.last : '';
              final msg = e['msg'] ?? 'Invalid value';
              return field.toString().isNotEmpty ? '$field: $msg' : '$msg';
            }
            return 'Invalid value';
          })
          .join(' | ');
    } else {
      message = 'Request failed.';
    }

    return ApiException(message, statusCode: response.statusCode);
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;

  /// HTTP status code of the failed response, when available (null for
  /// client-side failures like no internet/timeout — see ApiService._send).
  final int? statusCode;

  /// True kapag ang session ng customer ay expired/invalid — malaking
  /// senyales na dapat na silang ibalik sa login screen.
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}