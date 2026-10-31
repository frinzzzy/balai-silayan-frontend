import 'package:flutter/material.dart';
import '../services/admin_service.dart';

class StockManagementScreen extends StatefulWidget {
  final VoidCallback onRefresh;

  const StockManagementScreen({
    super.key,
    required this.onRefresh,
  });

  @override
  State<StockManagementScreen> createState() => StockManagementScreenState();
}

class StockManagementScreenState extends State<StockManagementScreen> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _inventoryItems = [];
  bool _isLoading = true;
  String _selectedCategoryFilter = 'All Items';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = ['All Items', 'Main Dishes', 'Drinks', 'Desserts', 'Low Stock'];

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 🔄 Public method para tawagin mula sa labas (AdminDashboard) para sa live refresh
  Future<void> loadInventorySilently() async {
    final items = await _adminService.fetchMenuInventory();
    if (mounted) {
      setState(() {
        _inventoryItems = items;
      });
    }
  }

  Future<void> _loadInventory() async {
    setState(() => _isLoading = true);
    final items = await _adminService.fetchMenuInventory();
    if (mounted) {
      setState(() {
        _inventoryItems = items;
        _isLoading = false;
      });
    }
  }

  void _showUpdateStockDialog(BuildContext context, Map<String, dynamic> item) {
    final int itemId = item['id'] ?? 0;
    final String itemName = item['name'] ?? 'Item';
    final int currentStock = item['stock_quantity'] ?? 50;
    final TextEditingController stockController = TextEditingController(text: currentStock.toString());
    String adjustmentType = 'RESTOCK';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFFFDFA),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Update Stock • $itemName',
            style: const TextStyle(fontFamily: 'Libre Baskerville', fontWeight: FontWeight.bold, color: Color(0xFF203F35), fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current On-Hand Quantity: $currentStock',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF687368)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF203F35)),
                decoration: InputDecoration(
                  labelText: 'New Stock Quantity',
                  filled: true,
                  fillColor: const Color(0xFFFFFDFA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Adjustment Reason / Type:', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF203F35))),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: adjustmentType,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF203F35)),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'RESTOCK', child: Text('RESTOCK (Delivery / Addition)')),
                  DropdownMenuItem(value: 'MANUAL_ADJUSTMENT', child: Text('MANUAL_ADJUSTMENT (Audit count)')),
                  DropdownMenuItem(value: 'SPOILAGE_WASTE', child: Text('SPOILAGE_WASTE (Damaged)')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => adjustmentType = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', color: Color(0xFF687368))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF203F35)),
              onPressed: () async {
                final int? newQty = int.tryParse(stockController.text.trim());
                if (newQty == null || newQty < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid non-negative quantity.')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                final success = await _adminService.updateItemStock(
                  itemId: itemId,
                  stockQuantity: newQty,
                  adjustmentType: adjustmentType,
                );
                if (success) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Stock successfully updated!'), backgroundColor: Color(0xFF10B981)),
                    );
                  }
                  _loadInventory();
                  widget.onRefresh();
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to update stock.'), backgroundColor: Color(0xFFEF4444)),
                    );
                  }
                  setState(() => _isLoading = false);
                }
              },
              child: const Text('Save Stock', style: TextStyle(fontFamily: 'Inter', color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filtered = _inventoryItems.where((item) {
      final String name = (item['name'] ?? '').toString().toLowerCase();
      final String cat = (item['category_name'] ?? item['category'] ?? '').toString().toLowerCase();
      final int stock = item['stock_quantity'] ?? 50;
      final int threshold = item['low_stock_threshold'] ?? 10;

      final bool matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
      bool matchesCategory = true;

      if (_selectedCategoryFilter == 'Main Dishes') {
        matchesCategory = cat.contains('main') || cat.contains('specialty') || cat.contains('sizzling') || cat.contains('pancit') || cat.contains('pasta');
      } else if (_selectedCategoryFilter == 'Drinks') {
        matchesCategory = cat.contains('drink') || cat.contains('beverage') || cat.contains('cooler');
      } else if (_selectedCategoryFilter == 'Desserts') {
        matchesCategory = cat.contains('dessert') || cat.contains('ice cream') || cat.contains('halo');
      } else if (_selectedCategoryFilter == 'Low Stock') {
        matchesCategory = stock <= threshold;
      }

      return matchesSearch && matchesCategory;
    }).toList();

    return Container(
      color: const Color(0xFFF8F4EC),
      child: RefreshIndicator(
        color: const Color(0xFF203F35),
        onRefresh: _loadInventory,
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
                    'Stock Management',
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
                    'Monitor live on-hand quantities, low stock warnings, and ingredient inventory levels.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF687368), height: 1.5),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDFA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5DFD3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 18, color: Color(0xFF687368)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF203F35)),
                        decoration: const InputDecoration(
                          hintText: 'Search inventory items...',
                          hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF687368)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: Color(0xFF687368)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategoryFilter == cat;
                    return ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF203F35),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF203F35),
                      backgroundColor: const Color(0xFFFFFDFA),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF203F35) : const Color(0xFFE5DFD3),
                        ),
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedCategoryFilter = cat);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: Color(0xFF203F35)),
                ),
              )
                  : filtered.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF687368)),
                      const SizedBox(height: 12),
                      const Text('No inventory items found.', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
                    ],
                  ),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final String name = item['name'] ?? 'Unnamed Dish';
                  final double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
                  final int stock = item['stock_quantity'] ?? 50;
                  final int threshold = item['low_stock_threshold'] ?? 10;
                  final String? imageUrl = item['image_url'];

                  String statusLabel = 'In Stock';
                  Color statusBg = const Color(0xFFD1FAE5);
                  Color statusFg = const Color(0xFF065F46);

                  if (stock == 0) {
                    statusLabel = 'Out of Stock';
                    statusBg = const Color(0xFFFEE2E2);
                    statusFg = const Color(0xFF991B1B);
                  } else if (stock <= threshold) {
                    statusLabel = 'Low Stock';
                    statusBg = const Color(0xFFF5EBD7);
                    statusFg = const Color(0xFF846228);
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDFA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5DFD3)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(41, 61, 48, 0.02),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEE7D9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: imageUrl != null && imageUrl.isNotEmpty
                                ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.restaurant, color: Color(0xFF203F35)),
                            )
                                : const Icon(Icons.restaurant, color: Color(0xFF203F35)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF203F35),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: statusFg,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₱${price.toStringAsFixed(2)} • Threshold: $threshold',
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF687368)),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'On-hand: ',
                                        style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF687368)),
                                      ),
                                      Text(
                                        '$stock units',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          color: stock == 0 ? const Color(0xFFEF4444) : const Color(0xFF203F35),
                                        ),
                                      ),
                                    ],
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF203F35),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                    onPressed: () => _showUpdateStockDialog(context, item),
                                    child: const Text('Update Stock', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}