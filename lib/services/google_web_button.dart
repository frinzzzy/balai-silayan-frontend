import 'package:flutter/widgets.dart';

import 'google_web_button_stub.dart'
    if (dart.library.js_interop) 'google_web_button_web.dart' as impl;

/// Web-only: ang Google-rendered na "Sign in with Google" button.
///
/// Sa Android/iOS/desktop, walang laman na widget lang ito — gamitin ang
/// custom na "Order Online" button doon.
Widget buildGoogleWebSignInButton() => impl.buildGoogleWebSignInButton();
