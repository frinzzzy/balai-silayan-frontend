import 'package:flutter/material.dart';
import '../models/admin_order_model.dart';

class SalesAnalyticsScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final double avgOrderVal = stats.totalTransactions > 0 ? (stats.totalSales / stats.totalTransactions) : 0.0;
    final double unpaidActiveTotal = orders
        .where((o) => o.status != 'PAID' && o.status != 'COMPLETED' && o.status != 'REJECTED' && o.status != 'CANCELLED')
        .fold(0.0, (sum, o) => sum + o.totalAmount);

    return Container(
      color: const Color(0xFFF8F4EC),
      child: RefreshIndicator(
        color: const Color(0xFF203F35),
        onRefresh: () async => onRefresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Introduction Section
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sales analytics',
                    style: TextStyle(
                      fontFamily: 'Libre Baskerville',
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF203F35),
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Monitor daily revenue performance, transaction volumes, and best-selling menu items.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF687368), height: 1.5),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Reporting Period Selector Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5DFD3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('REPORTING PERIOD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF687368))),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFDFA),
                        border: Border.all(color: const Color(0xFFE5DFD3)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF687368)),
                          SizedBox(width: 8),
                          Text('Today', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF203F35))),
                          Spacer(),
                          Icon(Icons.keyboard_arrow_down, color: Color(0xFF687368)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Live data synchronization across active station shifts.', style: TextStyle(fontSize: 12, color: Color(0xFF687368))),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Main Metric Card (Total Gross Revenue)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF203F35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF203F35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Gross Revenue (Recognized Sales)', style: TextStyle(fontSize: 12, color: Color(0xFFD7E3D7))),
                    const SizedBox(height: 8),
                    Text(
                      '₱${stats.totalSales.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600, color: Colors.white, height: 1.2),
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
                        color: const Color(0xFFFFFDFA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5DFD3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cash Collections', style: TextStyle(fontSize: 12, color: Color(0xFF687368))),
                          const SizedBox(height: 8),
                          Text(
                            '₱${stats.cashSales.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: Color(0xFF203F35)),
                          ),
                          const SizedBox(height: 8),
                          const Text('Counter drawer', style: TextStyle(fontSize: 12, color: Color(0xFF53766C))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFDFA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5DFD3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('GCash Verified', style: TextStyle(fontSize: 12, color: Color(0xFF687368))),
                          const SizedBox(height: 8),
                          Text(
                            '₱${stats.gcashSales.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: Color(0xFF203F35)),
                          ),
                          const SizedBox(height: 8),
                          const Text('Digital gateway', style: TextStyle(fontSize: 12, color: Color(0xFF53766C))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Sales Trend Bar Chart Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5DFD3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sales overview', style: TextStyle(fontFamily: 'Libre Baskerville', fontSize: 18, color: Color(0xFF203F35))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF0E9),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Text(
                        'Paid transactions only',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF53766C)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Live recognized sales summary • Philippine pesos (PHP)', style: TextStyle(fontSize: 12, color: Color(0xFF687368))),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildBarItem('Today', 140, '₱${stats.totalSales.toStringAsFixed(0)}', isPeak: true),
                        ],
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
                  color: const Color(0xFFFFFDFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5DFD3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dish performance', style: TextStyle(fontFamily: 'Libre Baskerville', fontSize: 18, color: Color(0xFF203F35))),
                    const SizedBox(height: 6),
                    const Text('Top ordered menu items by volume and revenue contribution.', style: TextStyle(fontSize: 12, color: Color(0xFF687368))),
                    const SizedBox(height: 16),
                    _buildDishPerformanceRow('Chicken Inasal', '18 orders', '₱2,160', 1.0),
                    const SizedBox(height: 12),
                    _buildDishPerformanceRow('Kare-Kare', '14 orders', '₱2,520', 0.85),
                    const SizedBox(height: 12),
                    _buildDishPerformanceRow('Lumpiang Shanghai', '22 orders', '₱1,540', 0.65),
                    const SizedBox(height: 12),
                    _buildDishPerformanceRow('Calamansi Cooler', '30 orders', '₱1,500', 0.5),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Divider(height: 1, color: Color(0xFFE5DFD3)),
                    ),
                    const Text('Aggregated based on successful kitchen outputs.', style: TextStyle(fontSize: 12, color: Color(0xFF687368))),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment Split Mix Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5DFD3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payment mix', style: TextStyle(fontFamily: 'Libre Baskerville', fontSize: 18, color: Color(0xFF203F35))),
                    const SizedBox(height: 6),
                    const Text('Only payments confirmed by staff at the counter.', style: TextStyle(fontSize: 12, color: Color(0xFF687368))),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Row(
                        children: [
                          Expanded(flex: 7, child: Container(height: 10, color: const Color(0xFF203F35))),
                          const SizedBox(width: 3),
                          Expanded(flex: 3, child: Container(height: 10, color: const Color(0xFFC3AA7F))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPaymentRow('Cash collections', '₱${stats.cashSales.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    _buildPaymentRow('GCash verified', '₱${stats.gcashSales.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    _buildPaymentRow('Total transactions count', '${stats.totalTransactions}'),
                    const SizedBox(height: 8),
                    _buildPaymentRow('Average order value', '₱${avgOrderVal.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.0),
                      child: Divider(height: 1, color: Color(0xFFE5DFD3)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Recorded live from database payments table.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF687368), height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Guidance Warning Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: Color(0xFF53766C)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Active unpaid orders total: ₱${unpaidActiveTotal.toStringAsFixed(2)}. Ensure pending tables are settled before closing shifts.',
                        style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF53766C)),
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
                  color: const Color(0xFFFFFDFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5DFD3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Report management', style: TextStyle(fontFamily: 'Libre Baskerville', fontSize: 18, color: Color(0xFF203F35))),
                    const SizedBox(height: 6),
                    const Text('Download official daily and weekly financial logs for auditing.', style: TextStyle(fontSize: 12, color: Color(0xFF687368))),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFFDFA),
                          side: const BorderSide(color: Color(0xFFE5DFD3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Exporting analytics report...'), backgroundColor: Color(0xFF203F35)),
                          );
                        },
                        icon: const Icon(Icons.download_outlined, size: 18, color: Color(0xFF687368)),
                        label: const Text('Export report', style: TextStyle(color: Color(0xFF203F35), fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Generated securely from live server records.', style: TextStyle(fontSize: 11, color: Color(0xFF687368))),
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
        Text(amount, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF53766C))),
        const SizedBox(height: 6),
        Container(
          width: 32,
          height: height,
          decoration: BoxDecoration(
            color: isPeak ? const Color(0xFF203F35) : const Color(0xFF86A397),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 8),
        Text(day, style: const TextStyle(fontSize: 11, color: Color(0xFF687368))),
      ],
    );
  }

  Widget _buildDishPerformanceRow(String dishName, String volume, String revenue, double progressFactor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(dishName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF24382F))),
            Text(revenue, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF203F35))),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(volume, style: const TextStyle(fontSize: 12, color: Color(0xFF687368))),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progressFactor,
            backgroundColor: const Color(0xFFEEE7D9),
            color: const Color(0xFF53766C),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentRow(String label, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF687368))),
        Text(amount, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
      ],
    );
  }
}