import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../user_session.dart';

/// Nagbabalik ng recent orders ng customer para sa "My Tickets" view.
///
/// Gamit ang session-scoped endpoint — hindi na public ang
/// `/customer/orders/recent`. Para sa Google takeout, customer-scope ang
/// query sa backend kaya lumalabas din ang orders mula sa lumang session.
class CustomerTicketService {
  CustomerTicketService._();

  static Future<List<dynamic>> fetchRecentTickets() async {
    final int? sessionId = UserSession.activeSessionId ??
        int.tryParse(UserSession.sessionId ?? '');
    final String? token = UserSession.activeSessionToken;

    if (sessionId == null || token == null || token.isEmpty) {
      throw Exception('Walang aktibong session. Mag-sign in ulit.');
    }

    final http.Response response = await http
        .get(
          Uri.parse(
            '${ApiConfig.baseUrl}/api/v1/customer/sessions/$sessionId/orders/recent',
          ),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Expired na ang session. Mag-sign in ulit.');
    }
    if (response.statusCode != 200) {
      throw Exception('Hindi ma-load ang tickets (${response.statusCode}).');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return <dynamic>[];

    final dynamic raw = decoded['data'] ?? decoded['orders'] ?? <dynamic>[];
    if (raw is! List) return <dynamic>[];

    return raw.whereType<Map<dynamic, dynamic>>().toList();
  }
}
