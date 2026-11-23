import 'package:flutter/widgets.dart';

/// Non-web fallback para sa [buildGoogleWebSignInButton].
///
/// Hindi ito ginagamit sa Android/iOS/desktop — sa mga platform na iyon,
/// ang custom na "Order Online" button ang ipinapakita.
Widget buildGoogleWebSignInButton() => const SizedBox.shrink();
