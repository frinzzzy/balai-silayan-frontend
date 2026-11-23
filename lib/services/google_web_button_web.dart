import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart';

/// Sa web, ang Google Identity Services (GIS) lang ang pinapayagang gumawa
/// ng sign-in UI — kaya `renderButton()` ang kailangan, hindi `authenticate()`.
///
/// Ang successful sign-in ay dumarating sa
/// `GoogleSignIn.instance.authenticationEvents`; doon natin ito pinapasa sa
/// `GoogleAuthService.webIdentityResults`.
Widget buildGoogleWebSignInButton() {
  return renderButton(
    configuration: GSIButtonConfiguration(
      type: GSIButtonType.standard,
      theme: GSIButtonTheme.outline,
      size: GSIButtonSize.large,
      text: GSIButtonText.signinWith,
      shape: GSIButtonShape.rectangular,
      logoAlignment: GSIButtonLogoAlignment.center,
      minimumWidth: 320,
    ),
  );
}
