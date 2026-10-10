import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'dart:convert';

class WaiterScreen extends StatefulWidget {
  final String? authToken;
  const WaiterScreen({super.key, this.authToken});

  @override
  State<WaiterScreen> createState() => _WaiterScreenState();
}

class _WaiterScreenState extends State<WaiterScreen> {
  List<Map<String, dynamic>> _tables = [];
  List<Map<String, dynamic>> _assistanceRequests = [];
  bool _isLoading = true;
  late io.Socket _socket;

  String get _baseUrl {
    if (kIsWeb) return 'http://localhost:5000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }
    return 'http://localhost:5000';
  }

  @override
  void initState() {
    super.initState();
    _fetchTableStatuses();
    _fetchAssistanceRequests();
    _initSocketListener();
  }

  void _initSocketListener() {
    _socket = io.io(
      _baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    _socket.onConnect((_) {
      _socket.emit('join_room', 'admin_live_monitoring');
    });

    _socket.on('table_status_updated', (_) {
      if (mounted) _fetchTableStatuses();
    });

    _socket.on('order_updated', (_) {
      if (mounted) _fetchTableStatuses();
    });
    _socket.on('table_session_closed', (_) {
      if (mounted) _fetchTableStatuses();
    });

    _socket.on('assistance_requested', (_) {
      if (mounted) _fetchAssistanceRequests();
    });

    _socket.on('assistance_resolved', (_) {
      if (mounted) _fetchAssistanceRequests();
    });
    _socket.connect();
  }

  @override
  void dispose() {
    _socket.disconnect();
    _socket.dispose();
    super.dispose();
  }

  Future<void> _fetchTableStatuses() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/tables'),
        headers: {
          if (widget.authToken != null)
            'Authorization': 'Bearer ${widget.authToken}',
        },
      );
      if (response.statusCode == 200 && mounted) {
        final resData = jsonDecode(response.body);
        final List<dynamic> list = resData['data'] ?? [];
        setState(() {
          _tables = List<Map<String, dynamic>>.from(list);
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAssistanceRequests() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/assistance'),
        headers: {
          if (widget.authToken != null)
            'Authorization': 'Bearer ${widget.authToken}',
        },
      );
      if (response.statusCode == 200 && mounted) {
        final resData = jsonDecode(response.body);
        final List<dynamic> list = resData['data'] ?? [];
        setState(() {
          _assistanceRequests = List<Map<String, dynamic>>.from(
            list.where(
              (req) =>
                  (req['status'] ?? 'PENDING').toString().toUpperCase() !=
                  'RESOLVED',
            ),
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _updateTableStatus(int tableId, String targetStatus) async {
    setState(() {
      for (var t in _tables) {
        if ((t['id'] == tableId) || (t['table_number'] == tableId)) {
          t['status'] = targetStatus;
        }
      }
    });

    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/api/v1/tables/$tableId/status'),
        headers: {
          'Content-Type': 'application/json',
          if (widget.authToken != null)
            'Authorization': 'Bearer ${widget.authToken}',
        },
        body: jsonEncode({'status': targetStatus}),
      );

      if (response.statusCode == 200) {
        _fetchTableStatuses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Table #$tableId status updated to $targetStatus'),
              duration: const Duration(seconds: 1),
              backgroundColor: const Color(0xFF1E293B),
            ),
          );
        }
      } else {
        _fetchTableStatuses();
      }
    } catch (e) {
      _fetchTableStatuses();
    }
  }

  Future<void> _resolveAssistance(int requestId) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/api/v1/assistance/$requestId/acknowledge'),
        headers: {
          'Content-Type': 'application/json',
          if (widget.authToken != null)
            'Authorization': 'Bearer ${widget.authToken}',
        },
        body: jsonEncode({'status': 'RESOLVED'}),
      );
      if (response.statusCode == 200) {
        _fetchAssistanceRequests();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Waiter Table Control Station',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00CEC9)),
            onPressed: () {
              _fetchTableStatuses();
              _fetchAssistanceRequests();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD67D41)),
            )
          : Column(
              children: [
                if (_assistanceRequests.isNotEmpty) _buildAssistanceBanner(),
                Expanded(
                  child: _tables.isEmpty
                      ? const Center(
                          child: Text(
                            'No table data available.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isDesktop ? 4 : 2,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: isDesktop ? 1.3 : 0.85,
                              ),
                          itemCount: _tables.length,
                          itemBuilder: (context, idx) {
                            final table = _tables[idx];
                            final int tableId = table['id'] ?? (idx + 1);
                            final int tableNum =
                                table['table_number'] ?? tableId;
                            final String status =
                                (table['status'] ?? 'AVAILABLE')
                                    .toString()
                                    .toUpperCase();

                            Color badgeColor = const Color(0xFF22C55E);
                            if (status == 'OCCUPIED')
                              badgeColor = const Color(0xFFD63031);
                            if (status == 'RESERVED')
                              badgeColor = const Color(0xFFEAB308);

                            return Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: badgeColor.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.table_restaurant_outlined,
                                              color: badgeColor,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                'Table $tableNum',
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: badgeColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (status == 'AVAILABLE')
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(
                                          Icons.sensor_door_outlined,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        label: const Text(
                                          'Seat Guest / Open',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFD63031,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        onPressed: () => _updateTableStatus(
                                          tableId,
                                          'OCCUPIED',
                                        ),
                                      ),
                                    ),
                                  if (status == 'OCCUPIED')
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(
                                          Icons.cleaning_services_outlined,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        label: const Text(
                                          'Clear & Available',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF22C55E,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        onPressed: () => _updateTableStatus(
                                          tableId,
                                          'AVAILABLE',
                                        ),
                                      ),
                                    ),
                                  if (status == 'RESERVED')
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        label: const Text(
                                          'Check-In Guest',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFD67D41,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        onPressed: () => _updateTableStatus(
                                          tableId,
                                          'OCCUPIED',
                                        ),
                                      ),
                                    ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        _updateTableStatus(
                                          tableId,
                                          status == 'RESERVED'
                                              ? 'AVAILABLE'
                                              : 'RESERVED',
                                        );
                                      },
                                      child: Text(
                                        status == 'RESERVED'
                                            ? 'Unreserve'
                                            : 'Mark Reserve',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFFEAB308),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildAssistanceBanner() {
    return Container(
      color: const Color(0xFFFF7675).withValues(alpha: 0.15),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.notifications_active,
                color: Color(0xFFFF7675),
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'ACTIVE WAITER CALL ALERTS',
                style: TextStyle(
                  color: Color(0xFFFF7675),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._assistanceRequests.map((req) {
            final reqId = req['request_id'] ?? req['id'] ?? 0;
            final tableNum = req['table_number'] ?? req['table_id'] ?? '?';
            final reqType =
                req['request_type'] ?? req['message'] ?? 'Waiter Call';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Table #$tableNum: $reqType',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(
                      Icons.check,
                      size: 14,
                      color: Color(0xFF22C55E),
                    ),
                    label: const Text(
                      'Resolve',
                      style: TextStyle(color: Color(0xFF22C55E), fontSize: 12),
                    ),
                    onPressed: () => _resolveAssistance(reqId),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
