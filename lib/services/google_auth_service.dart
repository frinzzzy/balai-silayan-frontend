import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../user_session.dart';

/// Verified Google customer bago mag-scan ng table QR.
///
/// Hindi ito may table/session — ang identity lang ang hawak natin dito. Ang
/// table session ay ibibigay ng backend pag nag-scan na ang customer.
class GoogleCustomerIdentity {
  final int customerId;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final String identityToken;

  const GoogleCustomerIdentity({
    required this.customerId,
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.identityToken,
  });
}

/// Error na may friendly message na pwedeng direktang ipakita sa UI.
class GoogleAuthException implements Exception {
  final String message;
  const GoogleAuthException(this.message);

  @override
  String toString() => message;
}

/// Login-first Google Sign-In.
///
/// 1. `google_sign_in` -> Google `id_token`
/// 2. `POST /api/v1/customer/auth/google/identity` -> backend verifies it
/// 3. Backend returns a customer identity JWT (walang virtual table)
/// 4. I-save sa [UserSession] at ipasa sa QR scan bilang Authorization header
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

  /// Kailangan ma-initialize bago i-render ang Google button sa web.
  static Future<void> ensureInitialized() => _ensureInitialized();

  /// Web-only: ang Google-rendered na button ang may hawak ng sign-in flow
  /// (hindi supported ang `authenticate()` sa web).
  static Stream<GoogleCustomerIdentity> webIdentityResults() async* {
    await _ensureInitialized();
    await for (final GoogleSignInAuthenticationEvent event
        in GoogleSignIn.instance.authenticationEvents) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        yield await _verifyIdentity(event.user);
      }
    }
  }

  /// Android/iOS: buksan ang Google account picker at i-verify sa backend.
  static Future<GoogleCustomerIdentity> signInCustomerIdentity() async {
    await _ensureInitialized();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const GoogleAuthException(
        'Sa web browser, gamitin ang "Sign in with Google" button na '
        'ibinigay ng Google.',
      );
    }

    final GoogleSignInAccount account;
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

    return _verifyIdentity(account);
  }

  static Future<GoogleCustomerIdentity> _verifyIdentity(
    GoogleSignInAccount account,
  ) async {
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
            Uri.parse(
              '${ApiConfig.baseUrl}/api/v1/customer/auth/google/identity',
            ),
            headers: const <String, String>{'Content-Type': 'application/json'},
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
    final Map<String, dynamic> payload = decoded['data'] is Map
        ? Map<String, dynamic>.from(decoded['data'] as Map)
        : Map<String, dynamic>.from(decoded);

    final Map<String, dynamic> customer = payload['customer'] is Map
        ? Map<String, dynamic>.from(payload['customer'] as Map)
        : <String, dynamic>{};

    final int? customerId = int.tryParse(
      (customer['id'] ?? payload['customer_id'] ?? '').toString(),
    );
    final String identityToken =
        (payload['identity_token'] ?? payload['token'] ?? '').toString().trim();

    if (customerId == null || customerId <= 0 || identityToken.isEmpty) {
      throw const GoogleAuthException(
        'Kulang ang identity details mula sa server. Subukan muli.',
      );
    }

    final String givenName = (customer['given_name'] ?? '').toString().trim();
    final String familyName = (customer['family_name'] ?? '').toString().trim();
    final String name = <String>[
      if (givenName.isNotEmpty) givenName,
      if (familyName.isNotEmpty) familyName,
    ].join(' ').trim();
    final String resolvedName = name.isNotEmpty
        ? name
        : (account.displayName?.trim().isNotEmpty == true
            ? account.displayName!.trim()
            : 'Guest');

    final String? email = (customer['email'] ?? account.email)?.toString();

    UserSession.setCustomerIdentity(
      customerId: customerId,
      identityToken: identityToken,
      displayName: resolvedName,
      email: email,
    );

    return GoogleCustomerIdentity(
      customerId: customerId,
      displayName: resolvedName,
      email: email,
      avatarUrl: (customer['avatar_url'] ?? account.photoUrl)?.toString(),
      identityToken: identityToken,
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
