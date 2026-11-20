import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../user_session.dart';

/// Resulta ng Google sign-in + backend session bootstrap para sa online
/// (takeout) na customer. Naglalaman ito ng display identity at ng
/// server-issued virtual table/session.
class GoogleAuthResult {
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final int tableId;
  final int? tableNumber;
  final int sessionId;

  const GoogleAuthResult({
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.tableId,
    required this.tableNumber,
    required this.sessionId,
  });
}

/// Error na may friendly message na pwedeng direktang ipakita sa UI.
class GoogleAuthException implements Exception {
  final String message;
  const GoogleAuthException(this.message);

  @override
  String toString() => message;
}

/// Google Sign-In para sa "Order Online / Takeout" door.
///
/// Flow:
/// 1. `google_sign_in` -> Google `id_token`
/// 2. `POST /api/v1/customer/auth/google` -> backend verifies the token
/// 3. Backend issues the existing `table_session` JWT scoped to the customer's
///    own virtual table (no shared Table 999).
/// 4. Dito natin ini-store sa [UserSession] para magamit ng existing
///    order/status/payment pipeline.
class GoogleAuthService {
  GoogleAuthService._();

  static Future<void>? _initialization;
  static bool _initialized = false;

  static bool get isConfigured =>
      ApiConfig.googleWebClientId.trim().isNotEmpty;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    if (!isConfigured) {
      throw const GoogleAuthException(
        'Hindi pa naka-configure ang Google Sign-In. Kailangan ng '
        'GOOGLE_WEB_CLIENT_ID bago ito magamit.',
      );
    }

    _initialization ??= GoogleSignIn.instance.initialize(
      // Sa web, clientId ang ginagamit. Sa Android/iOS, ang Web client ID ang
      // ipinapasa bilang serverClientId para makakuha ng idToken.
      clientId: kIsWeb ? ApiConfig.googleWebClientId : null,
      serverClientId: ApiConfig.googleWebClientId,
    );
    await _initialization;
    _initialized = true;
  }

  /// Buksan ang Google account picker at mag-set up ng takeout session.
  ///
  /// Throws [GoogleAuthException] na may friendly message kapag na-cancel,
  /// hindi configured, o tinanggihan ng backend ang token.
  static Future<GoogleAuthResult> signInWithGoogle() async {
    await _ensureInitialized();

    GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const GoogleAuthException('Cancelled ang Google Sign-In.');
      }
      throw GoogleAuthException(
        error.description?.trim().isNotEmpty == true
            ? error.description!.trim()
            : 'Hindi natuloy ang Google Sign-In. Subukan muli.',
      );
    } catch (_) {
      throw const GoogleAuthException(
        'Hindi natuloy ang Google Sign-In. Subukan muli.',
      );
    }

    final String? idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const GoogleAuthException(
        'Walang natanggap na Google ID token. I-check ang Google OAuth '
        'configuration (Web client ID / SHA-1) at subukan muli.',
      );
    }

    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/v1/customer/auth/google'),
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{'id_token': idToken}),
          )
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      throw const GoogleAuthException(
        'Hindi maabot ang server. I-check ang internet connection at subukan muli.',
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode != 200 || decoded is! Map) {
      final String message = decoded is Map
          ? (decoded['message']?.toString() ??
              'Hindi natanggap ng server ang Google sign-in.')
          : 'Hindi natanggap ng server ang Google sign-in.';
      throw GoogleAuthException(message);
    }

    // Tolerate both top-level and wrapped ({ data: {...} }) responses.
    final Map<String, dynamic> payload =
        decoded['data'] is Map
            ? Map<String, dynamic>.from(decoded['data'] as Map)
            : Map<String, dynamic>.from(decoded);

    final int? tableId = int.tryParse((payload['table_id'] ?? '').toString());
    final int? sessionId = int.tryParse(
      (payload['session_id'] ?? '').toString(),
    );
    final String? sessionToken = payload['session_token']?.toString();

    if (tableId == null || sessionId == null ||
        sessionToken == null || sessionToken.isEmpty) {
      throw const GoogleAuthException(
        'Kulang ang session details mula sa server. Subukan muli.',
      );
    }

    final Map<String, dynamic> customer = payload['customer'] is Map
        ? Map<String, dynamic>.from(payload['customer'] as Map)
        : <String, dynamic>{};
    final String givenName = (customer['given_name'] ?? '').toString().trim();
    final String familyName = (customer['family_name'] ?? '').toString().trim();
    final String displayName = <String>[
      if (givenName.isNotEmpty) givenName,
      if (familyName.isNotEmpty) familyName,
    ].join(' ').trim();

    final String resolvedName = displayName.isNotEmpty
        ? displayName
        : (account.displayName?.trim().isNotEmpty == true
            ? account.displayName!.trim()
            : 'Guest');

    // I-save sa existing session context. Server pa rin ang source of truth —
    // ang backend ang mag-o-override ng table/session sa order creation.
    UserSession.setSession(
      tableId: tableId,
      tableNumber: int.tryParse((payload['table_number'] ?? '').toString()) ??
          tableId,
      sessionNum: sessionId,
      token: sessionToken,
      takeout: true,
    );

    return GoogleAuthResult(
      displayName: resolvedName,
      email: (customer['email'] ?? account.email)?.toString(),
      avatarUrl: (customer['avatar_url'] ?? account.photoUrl)?.toString(),
      tableId: tableId,
      tableNumber: int.tryParse((payload['table_number'] ?? '').toString()),
      sessionId: sessionId,
    );
  }

  /// Best-effort sign out. Hindi natin binubura ang backend session dito.
  static Future<void> signOut() async {
    try {
      if (_initialized) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {
      // Ignore — local cleanup lang ang mahalaga.
    }
    UserSession.clearSession();
  }
}
