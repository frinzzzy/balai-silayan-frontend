import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../theme/admin_tokens.dart';
import '../../../theme/app_theme.dart';
import '../models/staff_user_model.dart';
import '../services/admin_service.dart';
import '../services/admin_staff_service.dart';

/// ADMIN-only screen: listahan ng staff accounts + "Create staff account".
///
/// Ang create flow ay naka-align sa `POST /api/v1/admin/staff`:
/// `name`, `username`, `role`, `temp_password`, at `pin` (CASHIER lang).
class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  static const List<String> _roles = <String>[
    'ADMIN',
    'CASHIER',
    'KITCHEN',
    'WAITER',
  ];

  final AdminStaffService _service = AdminStaffService();
  final TextEditingController _searchController = TextEditingController();

  List<StaffUser> _staff = <StaffUser>[];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  String _roleFilter = 'ALL';
  bool _showInactive = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onFilterChanged);
    _loadStaff();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onFilterChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onFilterChanged() => setState(() {});

  Future<void> _loadStaff({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() => _isRefreshing = true);
    }

    final StaffListResult result = await _service.fetchStaff();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _isRefreshing = false;
      _error = result.error;
      if (result.ok) _staff = result.staff;
    });
  }

  List<StaffUser> get _filteredStaff {
    final String query = _searchController.text.trim().toLowerCase();
    return _staff.where((StaffUser staff) {
      if (_roleFilter != 'ALL' && staff.role != _roleFilter) return false;
      if (!_showInactive && !staff.isActive) return false;
      if (query.isEmpty) return true;
      return staff.displayName.toLowerCase().contains(query) ||
          staff.username.toLowerCase().contains(query) ||
          staff.roleLabel.toLowerCase().contains(query);
    }).toList();
  }

  /// Confirms removal (soft deactivate) of a staff account.
  Future<void> _handleRemoveAccount(StaffUser staff) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AdminTheme.surfaceIvory,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminTokens.rLg),
        ),
        title: const Text(
          'Remove staff account',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AdminTheme.textDark,
          ),
        ),
        content: Text(
          'Remove "${staff.displayName}"? The account will be deactivated '
          'and will no longer be able to sign in. This action cannot be undone.',
          style: const TextStyle(
            fontSize: 13,
            color: AdminTheme.textDark,
            height: 1.4,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AdminTheme.mutedGray),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Remove',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final StaffActionResult result = await _service.deactivateStaff(
      staffId: staff.id,
    );
    if (!mounted) return;
    await _loadStaff(silent: true);
    if (!mounted) return;

    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message ?? 'Failed to remove staff account.',
            textAlign: TextAlign.center,
          ),
          backgroundColor: const Color(0xFF8E5136),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed ${staff.displayName}.'),
        backgroundColor: AdminTheme.deepGreen,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Confirms reactivation of a previously removed (deactivated) staff account.
  Future<void> _handleReactivateAccount(StaffUser staff) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AdminTheme.surfaceIvory,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminTokens.rLg),
        ),
        title: const Text(
          'Reactivate staff account',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AdminTheme.textDark,
          ),
        ),
        content: Text(
          'Reactivate "${staff.displayName}"? They will be able to sign in '
          'again using their username and password.',
          style: const TextStyle(
            fontSize: 13,
            color: AdminTheme.textDark,
            height: 1.4,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AdminTheme.mutedGray),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.deepGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Reactivate',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final StaffActionResult result = await _service.activateStaff(
      staffId: staff.id,
    );
    if (!mounted) return;
    await _loadStaff(silent: true);
    if (!mounted) return;

    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message ?? 'Failed to reactivate staff account.',
            textAlign: TextAlign.center,
          ),
          backgroundColor: const Color(0xFF8E5136),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Staff account reactivated.'),
        backgroundColor: AdminTheme.deepGreen,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _openCreateDialog() async {
    final _CreatedStaff? created = await showDialog<_CreatedStaff>(
      context: context,
      builder: (BuildContext context) =>
          _CreateStaffAccountDialog(service: _service),
    );
    if (created == null || !mounted) return;

    await _loadStaff(silent: true);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) =>
          _CredentialsDialog(created: created),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _loadStaff(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AdminTokens.s20),
        children: <Widget>[
          _buildHeader(),
          const SizedBox(height: AdminTokens.s16),
          if (!_isLoading && _error == null) _buildStats(),
          if (!_isLoading && _error == null) const SizedBox(height: AdminTokens.s16),
          _buildToolbar(),
          const SizedBox(height: AdminTokens.s16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _buildErrorCard(_error!)
          else if (_filteredStaff.isEmpty)
            _buildEmptyState()
          else
            ..._filteredStaff.map(
              (StaffUser staff) => Padding(
                padding: const EdgeInsets.only(bottom: AdminTokens.s12),
                child: _StaffCard(
                  staff: staff,
                  onRemove: staff.id == AdminService.currentUser?.id
                      ? null
                      : () => _handleRemoveAccount(staff),
                  onReactivate:
                      staff.id == AdminService.currentUser?.id
                      ? null
                      : () => _handleReactivateAccount(staff),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Staff Management', style: AdminTokens.h1),
              const SizedBox(height: AdminTokens.s4),
              Text(
                'Create staff accounts and see who is currently signed in.',
                style: AdminTokens.caption,
              ),
            ],
          ),
        ),
        const SizedBox(width: AdminTokens.s12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.deepGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: AdminTokens.s16,
              vertical: AdminTokens.s12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AdminTokens.rSm),
            ),
          ),
          onPressed: _openCreateDialog,
          icon: const Icon(Icons.person_add_alt_1, size: 18),
          label: const Text(
            'Create staff account',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    final int online = _staff.where((StaffUser s) => s.isOnline).length;
    final int active = _staff.where((StaffUser s) => s.isActive).length;
    final int inactive = _staff.length - active;

    return Wrap(
      spacing: AdminTokens.s12,
      runSpacing: AdminTokens.s12,
      children: <Widget>[
        _StatPill(label: 'Total staff', value: '${_staff.length}'),
        _StatPill(label: 'Online now', value: '$online', highlight: online > 0),
        _StatPill(label: 'Active', value: '$active'),
        _StatPill(label: 'Inactive', value: '$inactive'),
      ],
    );
  }

  Widget _buildToolbar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search name or username',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: AdminTheme.surfaceIvory,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AdminTokens.rSm),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AdminTokens.s8),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _isRefreshing ? null : () => _loadStaff(silent: true),
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: AdminTokens.s12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              _buildRoleChip('ALL', 'All'),
              ..._roles.map(
                (String role) => _buildRoleChip(
                  role,
                  StaffUser.roleLabelOf(role),
                ),
              ),
              const SizedBox(width: AdminTokens.s8),
              FilterChip(
                label: const Text('Show inactive'),
                selected: _showInactive,
                onSelected: (bool value) =>
                    setState(() => _showInactive = value),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleChip(String value, String label) {
    final bool selected = _roleFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: AdminTokens.s8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _roleFilter = value),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(AdminTokens.s16),
      decoration: AdminTokens.card(),
      child: Column(
        children: <Widget>[
          const Icon(Icons.cloud_off_outlined, color: AdminTheme.danger, size: 28),
          const SizedBox(height: AdminTokens.s8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AdminTokens.body,
          ),
          const SizedBox(height: AdminTokens.s12),
          OutlinedButton.icon(
            onPressed: () => _loadStaff(),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool hasAnyStaff = _staff.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(AdminTokens.s24),
      decoration: AdminTokens.card(),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.groups_2_outlined,
            size: 34,
            color: AdminTheme.mutedDark,
          ),
          const SizedBox(height: AdminTokens.s8),
          Text(
            hasAnyStaff
                ? 'No staff match this filter.'
                : 'No staff accounts yet. Create the first one.',
            style: AdminTokens.body,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.s16,
        vertical: AdminTokens.s12,
      ),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFEAF0E9) : AdminTheme.surfaceIvory,
        borderRadius: BorderRadius.circular(AdminTokens.rMd),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: highlight ? AdminTheme.successFg : AdminTheme.textDark,
            ),
          ),
          Text(label, style: AdminTokens.caption),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.staff,
    this.onRemove,
    this.onReactivate,
  });

  final StaffUser staff;

  /// Null kapag ang account na ito ay ang sarili ng kasalukuyang admin
  /// (hindi mo maaaring i-remove ang sarili mong account).
  final VoidCallback? onRemove;
  final VoidCallback? onReactivate;

  @override
  Widget build(BuildContext context) {
    final _RoleStyle roleStyle = _RoleStyle.of(staff.role);
    final String lastLogin = staff.lastLogin == null
        ? 'Never signed in'
        : DateFormat('MMM d, yyyy · h:mm a').format(staff.lastLogin!.toLocal());

    return Container(
      padding: const EdgeInsets.all(AdminTokens.s16),
      decoration: AdminTokens.card(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 22,
            backgroundColor: roleStyle.background,
            child: Text(
              staff.initial,
              style: TextStyle(
                color: roleStyle.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AdminTokens.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        staff.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AdminTheme.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: AdminTokens.s8),
                    _OnlineDot(isOnline: staff.isOnline),
                  ],
                ),
                const SizedBox(height: 2),
                Text('@${staff.username}', style: AdminTokens.caption),
                const SizedBox(height: AdminTokens.s8),
                Wrap(
                  spacing: AdminTokens.s8,
                  runSpacing: AdminTokens.s8,
                  children: <Widget>[
                    _Tag(
                      label: staff.roleLabel,
                      foreground: roleStyle.foreground,
                      background: roleStyle.background,
                    ),
                    _Tag(
                      label: staff.isActive ? 'Active' : 'Inactive',
                      foreground: staff.isActive
                          ? AdminTheme.successFg
                          : AdminTheme.danger,
                      background: staff.isActive
                          ? const Color(0xFFEAF0E9)
                          : const Color(0xFFF7EAE4),
                    ),
                    _Tag(
                      label: staff.isOnline ? 'Online' : 'Offline',
                      foreground: staff.isOnline
                          ? AdminTheme.successFg
                          : AdminTheme.mutedDark,
                      background: staff.isOnline
                          ? const Color(0xFFEAF0E9)
                          : const Color(0xFFF1EEE8),
                    ),
                  ],
                ),
                const SizedBox(height: AdminTokens.s8),
                Text('Last login: $lastLogin', style: AdminTokens.caption),
                const SizedBox(height: AdminTokens.s8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    if (staff.isActive)
                      TextButton.icon(
                        onPressed: onRemove,
                        icon: const Icon(
                          Icons.person_remove_outlined,
                          size: 16,
                          color: AdminTheme.danger,
                        ),
                        label: const Text(
                          'Remove account',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AdminTheme.danger,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: onReactivate,
                        icon: const Icon(
                          Icons.person_add_alt_1_outlined,
                          size: 16,
                          color: AdminTheme.deepGreen,
                        ),
                        label: const Text(
                          'Reactivate account',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AdminTheme.deepGreen,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? AdminTheme.successFg : const Color(0xFFC9C4BA),
      ),
    );
  }
}

class _RoleStyle {
  const _RoleStyle({required this.foreground, required this.background});

  final Color foreground;
  final Color background;

  static _RoleStyle of(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return const _RoleStyle(
          foreground: Color(0xFF8A6D3B),
          background: Color(0xFFF5EBD7),
        );
      case 'CASHIER':
        return const _RoleStyle(
          foreground: AdminTheme.successFg,
          background: Color(0xFFEAF0E9),
        );
      case 'KITCHEN':
        return const _RoleStyle(
          foreground: Color(0xFF8E5136),
          background: Color(0xFFF7EAE4),
        );
      default:
        return const _RoleStyle(
          foreground: AdminTheme.infoText,
          background: Color(0xFFEEF1F4),
        );
    }
  }
}

/// Data na ipinapakita isang beses pagkatapos ng create/reset.
class _CreatedStaff {
  const _CreatedStaff({
    required this.name,
    required this.username,
    required this.role,
    required this.password,
    this.pin,
  });

  final String name;
  final String username;
  final String role;
  final String password;
  final String? pin;
}

class _CreateStaffAccountDialog extends StatefulWidget {
  const _CreateStaffAccountDialog({required this.service});

  final AdminStaffService service;

  @override
  State<_CreateStaffAccountDialog> createState() =>
      _CreateStaffAccountDialogState();
}

class _CreateStaffAccountDialogState
    extends State<_CreateStaffAccountDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  String _role = 'CASHIER';
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  String _generatePassword() {
    const String alphabet =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final Random random = Random.secure();
    return List<String>.generate(
      12,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final String name = _nameController.text.trim();
    final String username = _usernameController.text.trim().toLowerCase();
    final String password = _passwordController.text;
    final String pin = _pinController.text.trim();

    final StaffActionResult result = await widget.service.createStaff(
      name: name,
      username: username,
      role: _role,
      password: password,
      pin: _role == 'CASHIER' && pin.isNotEmpty ? pin : null,
    );

    if (!mounted) return;

    if (result.ok) {
      Navigator.of(context).pop(
        _CreatedStaff(
          name: name,
          username: username,
          role: _role,
          password: password,
          pin: _role == 'CASHIER' && pin.isNotEmpty ? pin : null,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = false;
      _submitError = result.message ?? 'Failed to create staff account.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AdminTheme.surfaceIvory,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminTokens.rLg),
      ),
      title: const Text(
        'Create staff account',
        style: TextStyle(fontWeight: FontWeight.w700, color: AdminTheme.textDark),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration('Full name'),
                  validator: (String? value) {
                    final String text = (value ?? '').trim();
                    if (text.isEmpty) return 'Full name is required.';
                    if (text.length > 100) return 'Max 100 characters.';
                    return null;
                  },
                ),
                const SizedBox(height: AdminTokens.s12),
                TextFormField(
                  controller: _usernameController,
                  autocorrect: false,
                  decoration: _inputDecoration(
                    'Username',
                    helper: '3–50 chars: lowercase letters, numbers, . _ -',
                  ),
                  validator: (String? value) {
                    final String text = (value ?? '').trim().toLowerCase();
                    if (!RegExp(r'^[a-z0-9._-]{3,50}$').hasMatch(text)) {
                      return 'Use 3–50 lowercase letters, numbers, . _ -';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AdminTokens.s12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: _inputDecoration('Role'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                    DropdownMenuItem(value: 'CASHIER', child: Text('Cashier')),
                    DropdownMenuItem(value: 'KITCHEN', child: Text('Kitchen')),
                    DropdownMenuItem(value: 'WAITER', child: Text('Waiter')),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (String? value) {
                          if (value == null) return;
                          setState(() {
                            _role = value;
                            if (value != 'CASHIER') _pinController.clear();
                          });
                        },
                ),
                const SizedBox(height: AdminTokens.s12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration(
                    'Temporary password',
                    helper: '8–128 characters. Ibigay ito sa staff.',
                  ).copyWith(
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Generate password',
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  final String generated = _generatePassword();
                                  setState(() {
                                    _passwordController.text = generated;
                                    _obscurePassword = false;
                                  });
                                },
                          icon: const Icon(Icons.casino_outlined, size: 20),
                        ),
                        IconButton(
                          tooltip: _obscurePassword ? 'Show' : 'Hide',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  validator: (String? value) {
                    final int length = (value ?? '').length;
                    if (length < 8 || length > 128) {
                      return 'Password must be 8–128 characters.';
                    }
                    return null;
                  },
                ),
                if (_role == 'CASHIER') ...<Widget>[
                  const SizedBox(height: AdminTokens.s12),
                  TextFormField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: _inputDecoration(
                      'Cashier PIN (optional)',
                      helper: '4–6 digits for quick cashier login.',
                    ).copyWith(counterText: ''),
                    validator: (String? value) {
                      final String pin = (value ?? '').trim();
                      if (pin.isEmpty) return null;
                      if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
                        return 'PIN must be 4–6 digits.';
                      }
                      return null;
                    },
                  ),
                ],
                if (_submitError != null) ...<Widget>[
                  const SizedBox(height: AdminTokens.s12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AdminTokens.s12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7EAE4),
                      borderRadius: BorderRadius.circular(AdminTokens.rSm),
                      border: Border.all(
                        color: AdminTheme.danger.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      _submitError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminTheme.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AdminTheme.mutedGray),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.deepGreen,
            foregroundColor: Colors.white,
          ),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Create account',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, {String? helper}) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminTokens.rSm),
      ),
    );
  }
}

class _CredentialsDialog extends StatelessWidget {
  const _CredentialsDialog({required this.created});

  final _CreatedStaff created;

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AdminTheme.surfaceIvory,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminTokens.rLg),
      ),
      title: const Text(
        'Account created',
        style: TextStyle(fontWeight: FontWeight.w700, color: AdminTheme.textDark),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Ibigay ang mga detalye sa staff. Hindi na ito muling ipapakita.',
              style: AdminTokens.caption,
            ),
            const SizedBox(height: AdminTokens.s12),
            _CredentialRow(
              label: 'Name',
              value: created.name,
              onCopy: () => _copy(context, created.name),
            ),
            _CredentialRow(
              label: 'Username',
              value: created.username,
              onCopy: () => _copy(context, created.username),
            ),
            _CredentialRow(
              label: 'Role',
              value: StaffUser.roleLabelOf(created.role),
              onCopy: () => _copy(context, created.role),
            ),
            _CredentialRow(
              label: 'Temporary password',
              value: created.password,
              onCopy: () => _copy(context, created.password),
            ),
            if (created.pin != null)
              _CredentialRow(
                label: 'Cashier PIN',
                value: created.pin!,
                onCopy: () => _copy(context, created.pin!),
              ),
            const SizedBox(height: AdminTokens.s8),
            Text(
              'Itago ang mga detalye at ibigay lamang sa staff. '
              'Pwede mo itong i-reset anumang oras.',
              style: AdminTokens.caption,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.deepGreen,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AdminTokens.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 140,
            child: Text(label, style: AdminTokens.caption),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AdminTheme.textDark,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copy $label',
            visualDensity: VisualDensity.compact,
            onPressed: onCopy,
            icon: const Icon(Icons.copy, size: 16),
          ),
        ],
      ),
    );
  }
}
