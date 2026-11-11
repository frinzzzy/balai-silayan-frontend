import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/admin_order_model.dart';
import '../services/admin_service.dart';
import '../../../services/permission_service.dart';
import '../../../theme/app_theme.dart';

class SalesAnalyticsScreen extends StatefulWidget {
  final DailySalesStats stats;
  final List<AdminOrder> orders;
  final VoidCallback onRefresh;

  const SalesAnalyticsScreen({
    super.key,
    required this.stats,
    required this.orders,
    required this.onRefresh,
  });

  @override
  State<SalesAnalyticsScreen> createState() => _SalesAnalyticsScreenState();
}

class _SalesAnalyticsScreenState extends State<SalesAnalyticsScreen> {
  final AdminService _adminService = AdminService();
  late DailySalesStats _currentStats;
  List<dynamic> _chartBreakdown = [];
  List<TopDishItem> _topDishes = [];
  String _selectedPeriod = 'today'; // 'today', 'monthly', 'yearly', 'custom'
  DateTime _selectedDate = DateTime.now();
  DailySalesStats? _previousStats;
  bool _isLoading = false;
  final ScrollController _chartScrollController = ScrollController();

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
  final NumberFormat _currencyFormatInt = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _currentStats = widget.stats;
    _fetchFilteredStats(); // ✅ Agad na kinukuha ang tamang analytics data pagka-load para sa default period[cite: 17]
  }

  @override
  void dispose() {
    _chartScrollController.dispose();
    super.dispose();
  }

  // ✅ Live sync ng stats kapag nag-update ang background polling o socket kung 'today' ang naka-select[cite: 17]
  @override
  void didUpdateWidget(SalesAnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stats != oldWidget.stats && _selectedPeriod == 'today') {
      setState(() {
        _currentStats = widget.stats;
      });
    }
  }

  Future<void> _fetchFilteredStats() async {
    setState(() => _isLoading = true);
    try {
      String? startStr;
      String? endStr;
      if (_selectedPeriod == 'custom') {
        startStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
        endStr = startStr;
      } else if (_selectedPeriod == 'monthly') {
        startStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-01";
        final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
        endStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-$lastDay";
      } else if (_selectedPeriod == 'yearly') {
        startStr = "${_selectedDate.year}-01-01";
        endStr = "${_selectedDate.year}-12-31";
      }

      // Tawagin ang service na nagpapadala ng period at dates sa backend[cite: 17]
      final result = await _adminService.fetchSalesAnalyticsWithBreakdown(
        period: _selectedPeriod,
        startDate: startStr,
        endDate: endStr,
      );

      final DailySalesStats? previousStats = await _fetchPreviousPeriodStats();

      if (mounted) {
        setState(() {
          _currentStats = result['stats'];
          _chartBreakdown = result['breakdown'] ?? [];
          _topDishes = result['top_items'] ?? [];
          _previousStats = previousStats;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Kumukuha ng sales stats ng nakaraang period para sa growth/comparison indicator[cite: 17].
  Future<DailySalesStats?> _fetchPreviousPeriodStats() async {
    try {
      String prevPeriod = _selectedPeriod;
      String? prevStart;
      String? prevEnd;

      if (_selectedPeriod == 'today') {
        final DateTime yesterday = _selectedDate.subtract(const Duration(days: 1));
        prevPeriod = 'custom';
        prevStart = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
        prevEnd = prevStart;
      } else if (_selectedPeriod == 'monthly') {
        prevPeriod = 'monthly';
        final DateTime prevMonthStart = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
        prevStart = '${prevMonthStart.year}-${prevMonthStart.month.toString().padLeft(2, '0')}-${prevMonthStart.day.toString().padLeft(2, '0')}';
        final DateTime prevMonthEnd = DateTime(_selectedDate.year, _selectedDate.month, 0);
        prevEnd = '${prevMonthEnd.year}-${prevMonthEnd.month.toString().padLeft(2, '0')}-${prevMonthEnd.day.toString().padLeft(2, '0')}';
      } else if (_selectedPeriod == 'yearly') {
        prevPeriod = 'yearly';
        final int prevYear = _selectedDate.year - 1;
        prevStart = '$prevYear-01-01';
        prevEnd = '$prevYear-12-31';
      }

      final result = await _adminService.fetchSalesAnalyticsWithBreakdown(
        period: prevPeriod,
        startDate: prevStart,
        endDate: prevEnd,
      );
      return result['stats'] as DailySalesStats? ?? DailySalesStats(totalSales: 0.0, totalTransactions: 0, cashSales: 0.0, gcashSales: 0.0);
    } catch (_) {
      return null;
    }
  }

  void _navigatePeriod(int amount) {
    setState(() {
      if (_selectedPeriod == 'monthly') {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + amount, 1);
      } else if (_selectedPeriod == 'yearly') {
        _selectedDate = DateTime(_selectedDate.year + amount, _selectedDate.month, 1);
      } else {
        _selectedDate = _selectedDate.add(Duration(days: amount));
      }
    });
    _fetchFilteredStats();
  }

  @override
  Widget build(BuildContext context) {
    final double avgOrderVal = _currentStats.totalTransactions > 0 ? (_currentStats.totalSales / _currentStats.totalTransactions) : 0.0;
    final double unpaidActiveTotal = widget.orders
        .where((o) => o.status != 'PAID' && o.status != 'COMPLETED' && o.status != 'REJECTED' && o.status != 'CANCELLED')
        .fold(0.0, (sum, o) => sum + o.totalAmount);
    final double? growthPercent = (_previousStats != null && _previousStats!.totalSales > 0 && _currentStats.totalSales > 0)
        ? ((_currentStats.totalSales - _previousStats!.totalSales) / _previousStats!.totalSales) * 100
        : null;

    String periodLabel = 'Today (${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year})';
    if (_selectedPeriod == 'monthly') {
      final monthName = DateFormat('MMMM yyyy').format(_selectedDate);
      periodLabel = 'Monthly ($monthName)';
    } else if (_selectedPeriod == 'yearly') {
      periodLabel = 'Yearly (${_selectedDate.year})';
    } else if (_selectedPeriod == 'custom') {
      periodLabel = 'Specific Date (${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year})';
    }

    return Container(
      color: AdminTheme.background,
      child: RefreshIndicator(
        color: AdminTheme.textDark,
        onRefresh: () async {
          widget.onRefresh();
          await _fetchFilteredStats();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sales analytics',
                    style: TextStyle(
                      fontFamily: 'Libre Baskerville',
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      color: AdminTheme.textDark,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Monitor daily revenue performance, transaction volumes, and best-selling menu items.',
                    style: TextStyle(fontSize: 14, color: AdminTheme.mutedDark, height: 1.5),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Reporting Period Selector Card with Dropdown & Navigation Arrows
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AdminTheme.surfaceIvory,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('REPORTING PERIOD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminTheme.mutedDark)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AdminTheme.surfaceIvory,
                              border: Border.all(color: AdminTheme.border),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedPeriod,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(value: 'today', child: Text('Today', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AdminTheme.textDark))),
                                  DropdownMenuItem(value: 'monthly', child: Text('Monthly (e.g. September / February)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AdminTheme.textDark))),
                                  DropdownMenuItem(value: 'yearly', child: Text('Yearly (2026 / 2027)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AdminTheme.textDark))),
                                  DropdownMenuItem(value: 'custom', child: Text('Specific Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AdminTheme.textDark))),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    _selectPeriod(val);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Navigation Arrows para lumipat ng Period / Araw / Buwan / Taon[cite: 17]
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: AdminTheme.textDark),
                          tooltip: 'Previous',
                          onPressed: () => _navigatePeriod(-1),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: AdminTheme.textDark),
                          tooltip: 'Next',
                          onPressed: () => _navigatePeriod(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Active Period: $periodLabel', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.textDark)),
                        if (_isLoading)
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AdminTheme.textDark)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Main Metric Card (Total Gross Revenue)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AdminTheme.textDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminTheme.textDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Gross Revenue (Recognized Sales)', style: TextStyle(fontSize: 12, color: Color(0xFFD7E3D7))),
                    const SizedBox(height: 8),
                    Text(
                      _currencyFormat.format(_currentStats.totalSales),
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600, color: Colors.white, height: 1.2),
                    ),
                    const SizedBox(height: 8),
                    if (growthPercent != null)
                      Text(
                        'Growth vs previous period: ${growthPercent >= 0 ? '+' : ''}${growthPercent.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70, height: 1.2),
                      ),
                    const SizedBox(height: 8),
                    const Text('Real-time aggregated from settled table orders', style: TextStyle(fontSize: 12, color: Color(0xFFD7E3D7))),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Paid Metrics Row (Cash vs GCash Collections)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AdminTheme.surfaceIvory,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AdminTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cash Collections', style: TextStyle(fontSize: 12, color: AdminTheme.mutedDark)),
                          const SizedBox(height: 8),
                          Text(
                            _currencyFormat.format(_currentStats.cashSales),
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: AdminTheme.textDark),
                          ),
                          const SizedBox(height: 8),
                          const Text('Counter drawer', style: TextStyle(fontSize: 12, color: AdminTheme.successFg)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AdminTheme.surfaceIvory,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AdminTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('GCash Verified', style: TextStyle(fontSize: 12, color: AdminTheme.mutedDark)),
                          const SizedBox(height: 8),
                          Text(
                            _currencyFormat.format(_currentStats.gcashSales),
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: AdminTheme.textDark),
                          ),
                          const SizedBox(height: 8),
                          const Text('Digital gateway', style: TextStyle(fontSize: 12, color: AdminTheme.successFg)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Sales Trend Bar Chart Card with Horizontal Scrollbar & Smooth Physics
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AdminTheme.surfaceIvory,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sales overview', style: TextStyle(fontFamily: 'Libre Baskerville', fontSize: 18, color: AdminTheme.textDark)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AdminTheme.successBg,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Text(
                        'Paid transactions only',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminTheme.successFg),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Live recognized sales summary • Philippine pesos (PHP)', style: TextStyle(fontSize: 12, color: AdminTheme.mutedDark)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 210,
                      child: _chartBreakdown.isEmpty
                          ? const Center(child: Text('No data available for this period', style: TextStyle(fontSize: 12, color: AdminTheme.mutedDark)))
                          : Scrollbar(
                        controller: _chartScrollController,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: _chartScrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _chartBreakdown.length,
                          itemBuilder: (context, index) {
                            final item = _chartBreakdown[index];
                            final label = item['label'] ?? '';
                            final sales = double.tryParse(item['total_sales'].toString()) ?? 0.0;
                            double barHeight = sales > 0 ? (sales / (_currentStats.totalSales == 0 ? 1 : _currentStats.totalSales)) * 130 : 10;
                            if (barHeight < 10) barHeight = 10;
                            if (barHeight > 130) barHeight = 130;

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: _buildBarItem(label, barHeight, _currencyFormatInt.format(sales), isPeak: sales == _currentStats.totalSales && sales > 0),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Dish Performance Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AdminTheme.surfaceIvory,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dish performance', style: TextStyle(fontFamily: 'Libre Baskerville', fontSize: 18, color: AdminTheme.textDark)),
                    const SizedBox(height: 6),
                    const Text('Top ordered menu items by volume and revenue contribution.', style: TextStyle(fontSize: 12, color: AdminTheme.mutedDark)),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          children: [
                            CircularProgressIndicator(strokeWidth: 2, color: AdminTheme.textDark),
                            SizedBox(width: 8),
                            Text('Loading dish performance...', style: TextStyle(fontSize: 12, color: AdminTheme.mutedDark)),
                          ],
                        ),
                      )
                    else if (_topDishes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Text('No dish performance data available for this period.', style: TextStyle(fontSize: 12, color: AdminTheme.mutedDark)),
                      )
                    else ..._topDishes.map((dish) => _buildDishPerformanceRow(dish)),
                    if (_topDishes.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Divider(height: 1, color: Color(0xFFE5DFD3)),
                      ),
                    const Text('Aggregated based on successful kitchen outputs.', style: TextStyle(fontSize: 12, color: AdminTheme.mutedDark)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment Split Mix Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AdminTheme.surfaceIvory,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payment mix', style: TextStyle(fontFamily: 'Libre Baskerville', fontSize: 18, color: AdminTheme.textDark)),
                    const SizedBox(height: 6),
                    const Text('Only payments confirmed by staff at the counter.', style: TextStyle(fontSize: 12, color: AdminTheme.mutedDark)),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Row(
                        children: [
                          Expanded(flex: 7, child: Container(height: 10, color: AdminTheme.textDark)),
                          const SizedBox(width: 3),
                          Expanded(flex: 3, child: Container(height: 10, color: const Color(0xFFC3AA7F))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPaymentRow('Cash collections', _currencyFormat.format(_currentStats.cashSales)),
                    const SizedBox(height: 8),
                    _buildPaymentRow('GCash verified', _currencyFormat.format(_currentStats.gcashSales)),
                    const SizedBox(height: 8),
                    _buildPaymentRow('Total transactions count', '${_currentStats.totalTransactions}'),
                    const SizedBox(height: 8),
                    _buildPaymentRow('Average order value', _currencyFormat.format(avgOrderVal)),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.0),
                      child: Divider(height: 1, color: Color(0xFFE5DFD3)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Recorded live from database payments table.',
                      style: TextStyle(fontSize: 12, color: AdminTheme.mutedDark, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Guidance Warning Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AdminTheme.successBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: AdminTheme.successFg),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Active unpaid orders total: ${_currencyFormat.format(unpaidActiveTotal)}. Ensure pending tables are settled before closing shifts.',
                        style: const TextStyle(fontSize: 12, height: 1.5, color: AdminTheme.successFg),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Report Management / Export Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AdminTheme.surfaceIvory,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Report management', style: TextStyle(fontFamily: 'Libre Baskerville', fontSize: 18, color: AdminTheme.textDark)),
                    const SizedBox(height: 6),
                    const Text('Download official daily and weekly financial logs for auditing.', style: TextStyle(fontSize: 12, color: AdminTheme.mutedDark)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AdminTheme.surfaceIvory,
                          side: const BorderSide(color: Color(0xFFE5DFD3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          final bool storageGranted = await PermissionService.requestStoragePermission();
                          if (!context.mounted) return;
                          if (!storageGranted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Storage permission needed to export the sales report.'), backgroundColor: AdminTheme.textDark),
                            );
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Exporting analytics report...'), backgroundColor: AdminTheme.textDark),
                          );
                        },
                        icon: const Icon(Icons.download_outlined, size: 18, color: AdminTheme.mutedDark),
                        label: const Text('Export report', style: TextStyle(color: AdminTheme.textDark, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Generated securely from live server records.', style: TextStyle(fontSize: 11, color: AdminTheme.mutedDark)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarItem(String day, double height, String amount, {bool isPeak = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(amount, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdminTheme.successFg)),
        const SizedBox(height: 6),
        Container(
          width: 32,
          height: height,
          decoration: BoxDecoration(
            color: isPeak ? AdminTheme.textDark : const Color(0xFF86A397),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 8),
        Text(day, style: const TextStyle(fontSize: 11, color: AdminTheme.mutedDark)),
      ],
    );
  }

  Widget _buildDishPerformanceRow(TopDishItem dish) {
    final double maxRevenue = _topDishes.fold<double>(0.0, (m, d) => d.revenue > m ? d.revenue : m);
    final double progress = maxRevenue > 0 ? (dish.revenue / maxRevenue).clamp(0.0, 1.0).toDouble() : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                dish.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF24382F)),
              ),
            ),
            Text(
              _currencyFormat.format(dish.revenue),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AdminTheme.textDark),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${dish.quantity} orders', style: const TextStyle(fontSize: 12, color: AdminTheme.mutedDark)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFFEEE7D9),
            color: AdminTheme.successFg,
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  void _selectPeriod(String value) {
    setState(() => _selectedPeriod = value);
    if (value == 'custom') {
      showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2023),
        lastDate: DateTime(2030),
      ).then((picked) {
        if (picked != null) {
          setState(() => _selectedDate = picked);
          _fetchFilteredStats();
        }
      });
    } else {
      _fetchFilteredStats();
    }
  }

  Widget _buildPaymentRow(String label, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AdminTheme.mutedDark)),
        Text(amount, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AdminTheme.textDark)),
      ],
    );
  }
}