/// Staff account na bumabalik mula sa `/api/v1/admin/staff` at
/// `/api/v1/auth/login`.
class StaffUser {
  const StaffUser({
    required this.id,
    required this.fullName,
    required this.username,
    required this.role,
    required this.isActive,
    required this.isOnline,
    this.lastLogin,
  });

  final int id;
  final String fullName;
  final String username;
  final String role; // ADMIN | CASHIER | KITCHEN | WAITER
  final bool isActive;
  final bool isOnline;
  final DateTime? lastLogin;

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    final dynamic rawLastLogin = json['last_login'] ?? json['last_login_at'];
    return StaffUser(
      id: int.tryParse((json['id'] ?? '').toString()) ?? 0,
      fullName: (json['full_name'] ?? '').toString().trim(),
      username: (json['username'] ?? '').toString().trim(),
      role: (json['role'] ?? '').toString().toUpperCase(),
      isActive: _asBool(json['is_active'], fallback: true),
      isOnline: _asBool(json['is_online'], fallback: false),
      lastLogin: DateTime.tryParse(rawLastLogin?.toString() ?? ''),
    );
  }

  /// Full name kung meron; username ang fallback para sa lumang seeded
  /// accounts na walang `full_name`.
  String get displayName => fullName.isNotEmpty ? fullName : username;

  String get initial {
    final String source = displayName.trim();
    return source.isEmpty ? '?' : source.substring(0, 1).toUpperCase();
  }

  String get roleLabel => roleLabelOf(role);

  bool get isAdmin => role == 'ADMIN';

  static String roleLabelOf(String rawRole) {
    switch (rawRole.toUpperCase()) {
      case 'ADMIN':
        return 'Admin';
      case 'CASHIER':
        return 'Cashier';
      case 'KITCHEN':
        return 'Kitchen';
      case 'WAITER':
        return 'Waiter';
      default:
        return rawRole.isEmpty ? 'Unknown' : rawRole;
    }
  }

  static bool _asBool(dynamic value, {required bool fallback}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String normalized = value.toString().toLowerCase();
    if (normalized == 'true' || normalized == 't' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == 'f' || normalized == '0') {
      return false;
    }
    return fallback;
  }
}
