import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Structural data schema matching table and customer reservations database columns
class TableReservation {
  final int id;
  final String customerName;
  final String contactNumber;
  final int partySize;
  final String reservationTime;
  final int? tableId;
  final String? tableNumber;
  final String status;

  TableReservation({
    required this.id,
    required this.customerName,
    required this.contactNumber,
    required this.partySize,
    required this.reservationTime,
    this.tableId,
    this.tableNumber,
    required this.status,
  });

  factory TableReservation.fromJson(Map<String, dynamic> json) {
    String rawTime = json['reservation_time']?.toString() ?? '';
    String rawDate = json['event_date']?.toString() ?? '';
    String timeDisplay = rawDate.isNotEmpty && rawTime.isNotEmpty
        ? "$rawDate - $rawTime"
        : (rawTime.isNotEmpty ? rawTime : (rawDate.isNotEmpty ? rawDate : 'Scheduled Time'));

    return TableReservation(
      id: json['id'] ?? 0,
      customerName: json['customer_name'] ?? json['name'] ?? 'Unknown Guest',
      contactNumber: json['contact_number'] ?? json['contact_info'] ?? '',
      partySize: json['party_size'] ?? 1,
      reservationTime: timeDisplay,
      tableId: json['table_id'],
      tableNumber: json['table_number']?.toString() ?? json['table_id']?.toString() ?? 'Unassigned',
      status: json['status']?.toString().toUpperCase() ?? 'PENDING',
    );
  }
}

// Structural data schema matching workstation.js state mutations
class WorkstationUnit {
  final String id;
  final bool isLocked;
  final String allocationCode;

  WorkstationUnit({
    required this.id,
    required this.isLocked,
    required this.allocationCode,
  });
}

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TableReservation> _reservationsRepository = [];
  List<WorkstationUnit> _workstationsRepository = [];
  bool _isLoading = true;

  // Fallback production seed arrays matching database mock environments
  final List<TableReservation> _fallbackReservations = [
    TableReservation(
      id: 301,
      customerName: "Frinz Gerard",
      contactNumber: "09123456789",
      partySize: 4,
      reservationTime: "Oct 12, 2026 - 09:00 AM",
      tableNumber: "01",
      status: "CONFIRMED",
    ),
    TableReservation(
      id: 302,
      customerName: "Clarence Pogi",
      contactNumber: "09987654321",
      partySize: 2,
      reservationTime: "Oct 15, 2026 - 02:00 PM",
      tableNumber: "02",
      status: "PENDING",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _synchronizeAllocationRecords();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _synchronizeAllocationRecords() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/v1/event-reservations'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedData = jsonDecode(response.body);
        final List<dynamic> recordsList = decodedData['data'] ?? [];
        setState(() {
          _reservationsRepository = recordsList.map((item) => TableReservation.fromJson(item)).toList();
        });
      } else {
        _tryFallbackReservationEndpoint();
      }
    } catch (e) {
      _tryFallbackReservationEndpoint();
    }

    setState(() {
      _workstationsRepository = List.generate(12, (idx) {
        return WorkstationUnit(
          id: 'WS-${101 + idx}',
          isLocked: idx % 4 == 0,
          allocationCode: idx % 4 == 0 ? 'SECURE_CTX_${50 + idx}' : 'VACANT',
        );
      });
      _isLoading = false;
    });
  }

  Future<void> _tryFallbackReservationEndpoint() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/v1/event-reservations'),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedData = jsonDecode(response.body);
        final List<dynamic> recordsList = decodedData['data'] ?? [];
        setState(() {
          _reservationsRepository = recordsList.map((item) => TableReservation.fromJson(item)).toList();
        });
        return;
      }
    } catch (_) {}

    setState(() {
      _reservationsRepository = _fallbackReservations;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Asset Reservations', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFD67D41),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFFD67D41),
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: "Active Bookings"),
            Tab(text: "Workstation Terminal Grid"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD67D41)))
          : TabBarView(
        controller: _tabController,
        children: [
          _renderEventReservationsView(),
          _renderWorkstationsGridView(),
        ],
      ),
    );
  }

  Widget _renderEventReservationsView() {
    if (_reservationsRepository.isEmpty) {
      return const Center(child: Text('No active event bookings resolved in database repository.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reservationsRepository.length,
      itemBuilder: (context, idx) {
        final reservation = _reservationsRepository[idx];
        final bool isConfirmed = reservation.status == 'CONFIRMED' || reservation.status == 'CHECKED_IN';

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 12, offset: const Offset(0, 4))],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.meeting_room_outlined, color: Color(0xFF64748B), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${reservation.customerName} (Party: ${reservation.partySize})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Table #${reservation.tableNumber}  •  ${reservation.reservationTime}',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isConfirmed ? const Color(0xFFE2FBE7) : const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    reservation.status,
                    style: TextStyle(
                      color: isConfirmed ? const Color(0xFF198754) : const Color(0xFF856404),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _renderWorkstationsGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.9,
      ),
      itemCount: _workstationsRepository.length,
      itemBuilder: (context, idx) {
        final terminal = _workstationsRepository[idx];
        return InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Selected Terminal Target: ${terminal.id} [Context: ${terminal.allocationCode}]')),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: terminal.isLocked ? const Color(0xFFFF7675).withValues(alpha: 0.3) : Colors.grey.shade200,
                width: terminal.isLocked ? 1.5 : 1.0,
              ),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.computer_rounded,
                  size: 28,
                  color: terminal.isLocked ? const Color(0xFFFF7675) : const Color(0xFFD67D41),
                ),
                const SizedBox(height: 8),
                Text(terminal.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                const SizedBox(height: 2),
                Text(
                  terminal.isLocked ? 'OCCUPIED' : 'AVAILABLE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: terminal.isLocked ? const Color(0xFFFF7675) : const Color(0xFF00CEC9),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}