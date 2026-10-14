import 'package:flutter/material.dart';
import '../models/admin_order_model.dart';

class SalesAnalyticsScreen extends StatelessWidget {
  final DailySalesStats stats;
  final VoidCallback onRefresh;

  const SalesAnalyticsScreen({
    super.key,
    required this.stats,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFF1B3B2B),
      onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Introduction & Export Report Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'A CLEARER VIEW OF YOUR TABLE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFA47C3D), letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sales analytics',
                      style: TextStyle(fontFamily: 'Libre Baskerville', fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Recognized sales, paid orders and the dishes guests come back for.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF687368)),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFFDFA),
                    side: const BorderSide(color: Color(0xFFE5DFD3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.download_outlined, size: 16, color: Color(0xFF203F35)),
                  label: const Text('Export report', style: TextStyle(color: Color(0xFF203F35), fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Exporting analytics report...'), backgroundColor: Color(0xFF1B3B2B)),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Reporting Filters Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5DFD3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F4EC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE5DFD3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF203F35)),
                            SizedBox(width: 8),
                            Text('1–7 October 2026', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F4EC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE5DFD3)),
                        ),
                        child: const Row(
                          children: [
                            Text('Last 7 complete days', style: TextStyle(fontSize: 12, color: Color(0xFF203F35))),
                            SizedBox(width: 8),
                            Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFF203F35)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Compared with 24–30 September 2026',
                    style: TextStyle(fontSize: 12, color: Color(0xFF687368)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4 Sales Metrics (KPI Cards in a row)
            Row(
              children: [
                Expanded(child: _buildMetricCard('Recognized sales', '₱${stats.totalSales.toStringAsFixed(0)}', '↑ 11.4% - previous ₱75,600', isDark: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricCard('Staff-confirmed paid orders', '${stats.totalTransactions}', '↑ 2.8% - previous 70 orders')),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricCard('Average paid order value', '₱1,170', '↑ 8.3% - previous ₱1,080')),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricCard('Accepted, unpaid session totals', '₱5,160', 'Today at 12:42 PM - not sales')),
              ],
            ),
            const SizedBox(height: 24),

            // Trend & Payment Mix Section
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sales Trend Bar Chart Mockup
                Expanded(
                  flex: 7,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDFA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5DFD3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'The week at a glance',
                              style: TextStyle(fontFamily: 'Libre Baskerville', fontSize: 20, color: Color(0xFF203F35)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF0E9),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Text(
                                'Paid transactions only',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF53766C)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Daily recognized sales • Philippine pesos (PHP)',
                          style: TextStyle(fontSize: 12, color: Color(0xFF687368)),
                        ),
                        const SizedBox(height: 28),
                        // Bar Chart Rows
                        SizedBox(
                          height: 190,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildBarItem('Thu 01', 112, '₱9,560'),
                              _buildBarItem('Fri 02', 133, '₱11,900'),
                              _buildBarItem('Sat 03', 126, '₱10,500'),
                              _buildBarItem('Sun 04', 147, '₱12,600'),
                              _buildBarItem('Mon 05', 168, '₱14,400'),
                              _buildBarItem('Tue 06', 189, '₱16,200', isPeak: true),
                              _buildBarItem('Wed 07', 107, '₱9,340'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                // Payment mix
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDFA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5DFD3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment mix',
                          style: TextStyle(fontFamily: 'Libre Baskerville', fontSize: 20, color: Color(0xFF203F35)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Only payments confirmed by staff at the counter.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF687368)),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '₱${stats.totalSales.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
                        ),
                        const SizedBox(height: 16),
                        // Split Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Row(
                            children: [
                              Expanded(flex: 66, child: Container(height: 14, color: const Color(0xFF1B3B2B))),
                              const SizedBox(width: 3),
                              Expanded(flex: 34, child: Container(height: 14, color: const Color(0xFFA47C3D))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildPaymentRow('Cash - 65.7%', '₱${stats.cashSales.toStringAsFixed(0)}'),
                        const SizedBox(height: 8),
                        _buildPaymentRow('Card / GCash - 33.3%', '₱${stats.gcashSales.toStringAsFixed(0)}'),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Divider(height: 1, color: Color(0xFFE5DFD3)),
                        ),
                        const Text(
                          'No online gateway. Payment method is recorded by restaurant staff.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF687368), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Best-selling dishes & What counts as sales
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDFA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5DFD3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Best-selling dishes',
                              style: TextStyle(fontFamily: 'Libre Baskerville', fontSize: 20, color: Color(0xFF203F35)),
                            ),
                            const Text(
                              'Ranked by paid revenue',
                              style: TextStyle(fontSize: 11, color: Color(0xFF687368)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('DISH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF687368))),
                            Row(
                              children: [
                                Text('QTY SOLD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF687368))),
                                SizedBox(width: 40),
                                Text('REVENUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF687368))),
                                SizedBox(width: 40),
                                Text('RELATIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF687368))),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 20, color: Color(0xFFE5DFD3)),
                        _buildDishRow('Chicken Inasal', 84, '₱23,940', 0.9),
                        _buildDishRow('Kare-kare', 48, '₱20,400', 0.75),
                        _buildDishRow('Lumpiang Shanghai', 60, '₱11,700', 0.5),
                        _buildDishRow('Calamansi Cooler', 120, '₱10,200', 0.4),
                        _buildDishRow('Bibingka', 50, '₱8,250', 0.3),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDFA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5DFD3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'What counts as sales',
                          style: TextStyle(fontFamily: 'Libre Baskerville', fontSize: 20, color: Color(0xFF203F35)),
                        ),
                        const SizedBox(height: 16),
                        _buildSalesCountRow('Paid • reporting week', '72 orders'),
                        const SizedBox(height: 8),
                        _buildSalesCountRow('Recognized', '₱${stats.totalSales.toStringAsFixed(0)}', isBold: true),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Divider(height: 1, color: Color(0xFFE5DFD3)),
                        ),
                        const Text('TODAY - EXCLUDED FROM SALES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFA47C3D))),
                        const SizedBox(height: 8),
                        _buildSalesCountRow('Accepted, unpaid - 4 orders', '₱5,160'),
                        const SizedBox(height: 6),
                        _buildSalesCountRow('Pending review - 2 orders', '₱740'),
                        const SizedBox(height: 6),
                        _buildSalesCountRow('Declined - 1 order', '₱695'),
                        const SizedBox(height: 6),
                        _buildSalesCountRow('Cancelled - 1 order', '₱330'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, String comparison, {bool isDark = false}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B3B2B) : const Color(0xFFFFFDFA),
        borderRadius: BorderRadius.circular(14),
        border: isDark ? null : Border.all(color: const Color(0xFFE5DFD3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFB3C3B8) : const Color(0xFF687368)),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1B3B2B)),
          ),
          const SizedBox(height: 6),
          Text(
            comparison,
            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFD7E3D7) : const Color(0xFF53766C)),
          ),
        ],
      ),
    );
  }

  Widget _buildBarItem(String day, double height, String amount, {bool isPeak = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(amount, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF53766C))),
        const SizedBox(height: 6),
        Container(
          width: 42,
          height: height,
          decoration: BoxDecoration(
            color: isPeak ? const Color(0xFF1B3B2B) : const Color(0xFF86A397),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          ),
        ),
        const SizedBox(height: 8),
        Text(day, style: const TextStyle(fontSize: 10, color: Color(0xFF687368))),
      ],
    );
  }

  Widget _buildPaymentRow(String label, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF687368))),
        Text(amount, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
      ],
    );
  }

  Widget _buildDishRow(String name, int qty, String revenue, double relativeWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEE7D9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(name.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B))),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF24382F))),
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(width: 60, child: Text('$qty', style: const TextStyle(fontSize: 12, color: Color(0xFF24382F)))),
              SizedBox(width: 80, child: Text(revenue, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B)))),
              SizedBox(
                width: 90,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: relativeWidth,
                    backgroundColor: const Color(0xFFEEE7D9),
                    color: const Color(0xFF53766C),
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalesCountRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: isBold ? const Color(0xFF1B3B2B) : const Color(0xFF687368), fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: isBold ? 15 : 13, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, color: const Color(0xFF1B3B2B))),
      ],
    );
  }
}
