import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/menu_images.dart';

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
  List<Map<String, dynamic>> _menuCategories = [];
  bool _isLoading = true;
  bool _loadFailed = false;
  // 'all' | 'low' | 'cat:<category_id>'
  String _selectedCategoryKey = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
    await _fetchInventoryAndCategories(showLoading: false);
  }

  Future<void> _loadInventory() async {
    await _fetchInventoryAndCategories(showLoading: true);
  }

  Future<void> _fetchInventoryAndCategories({required bool showLoading}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
      });
    }

    final List<Object> results = await Future.wait<Object>([
      _adminService.fetchMenuInventory(),
      _adminService.fetchMenuCategories(),
    ]);
    final List<Map<String, dynamic>> items =
        (results[0] as List).cast<Map<String, dynamic>>();
    final List<Map<String, dynamic>> categories =
        (results[1] as List).cast<Map<String, dynamic>>();

    if (!mounted) return;

    setState(() {
      _inventoryItems = items;
      // Huwag i-blanko ang dating categories kapag bigo ang categories API —
      // mas mabuti ang lumang listahan kaysa mawala lahat ng chips.
      if (categories.isNotEmpty) {
        _menuCategories = categories;
      }
      _isLoading = false;
      _loadFailed = items.isEmpty && categories.isEmpty;
      if (!_availableCategoryKeys.contains(_selectedCategoryKey)) {
        _selectedCategoryKey = 'all';
      }
    });
  }

  Set<String> get _availableCategoryKeys => <String>{
        'all',
        'low',
        ..._menuCategories.map(
          (category) => 'cat:${(category['id'] ?? '').toString()}',
        ),
      };

  List<_StockCategoryFilter> get _categoryFilters => <_StockCategoryFilter>[
        const _StockCategoryFilter(key: 'low', label: 'Low Stock'),
        const _StockCategoryFilter(key: 'all', label: 'All Items'),
        ..._menuCategories.map(
          (category) => _StockCategoryFilter(
            key: 'cat:${(category['id'] ?? '').toString()}',
            label: (category['name'] ?? 'Category').toString(),
          ),
        ),
      ];

  int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _categoryNameFor(Map<String, dynamic> item) {
    final dynamic rawName = item['category_name'] ?? item['category'];
    if (rawName != null && rawName.toString().trim().isNotEmpty) {
      return rawName.toString();
    }
    final int? categoryId =
        int.tryParse((item['category_id'] ?? '').toString());
    if (categoryId != null) {
      for (final Map<String, dynamic> category in _menuCategories) {
        final int? id = int.tryParse((category['id'] ?? '').toString());
        if (id == categoryId) {
          return (category['name'] ?? 'Category $categoryId').toString();
        }
      }
    }
    return 'Uncategorized';
  }

  void _showUpdateStockDialog(BuildContext context, Map<String, dynamic> item) {
    final int itemId = _asInt(item['id'], 0);
    final String itemName = item['name'] ?? 'Item';
    final int currentStock = _asInt(item['stock_quantity'], 50);
    final TextEditingController stockController = TextEditingController(text: currentStock.toString());
    String adjustmentType = 'RESTOCK';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AdminTheme.surfaceIvory,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Update Stock • $itemName',
            style: const TextStyle(fontFamily: 'Libre Baskerville', fontWeight: FontWeight.bold, color: AdminTheme.textDark, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current On-Hand Quantity: $currentStock',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AdminTheme.mutedDark),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AdminTheme.textDark),
                decoration: InputDecoration(
                  labelText: 'New Stock Quantity',
                  filled: true,
                  fillColor: AdminTheme.surfaceIvory,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Adjustment Reason / Type:', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: AdminTheme.textDark)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: adjustmentType,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AdminTheme.textDark),
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
              child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', color: AdminTheme.mutedDark)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.textDark),
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
    final bool lowStockOnly = _selectedCategoryKey == 'low';
    final int? selectedCategoryId = _selectedCategoryKey.startsWith('cat:')
        ? int.tryParse(_selectedCategoryKey.substring(4))
        : null;

    List<Map<String, dynamic>> filtered = _inventoryItems.where((item) {
      final String name = (item['name'] ?? '').toString().toLowerCase();
      final int stock = _asInt(item['stock_quantity'], 50);
      final int threshold = _asInt(item['low_stock_threshold'], 10);
      final int? categoryId =
          int.tryParse((item['category_id'] ?? '').toString());

      final bool matchesSearch =
          _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
      bool matchesCategory = true;

      if (lowStockOnly) {
        matchesCategory = stock <= threshold;
      } else if (selectedCategoryId != null) {
        matchesCategory = categoryId == selectedCategoryId;
      }

      return matchesSearch && matchesCategory;
    }).toList();

    return Container(
      color: AdminTheme.background,
      child: RefreshIndicator(
        color: AdminTheme.textDark,
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
                      color: AdminTheme.textDark,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Monitor live on-hand quantities, low stock warnings, and ingredient inventory levels.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AdminTheme.mutedDark, height: 1.5),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AdminTheme.surfaceIvory,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AdminTheme.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 18, color: AdminTheme.mutedDark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AdminTheme.textDark),
                        decoration: const InputDecoration(
                          hintText: 'Search inventory items...',
                          hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AdminTheme.mutedDark),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: AdminTheme.mutedDark),
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
                  itemCount: _categoryFilters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final _StockCategoryFilter category = _categoryFilters[index];
                    final isSelected = _selectedCategoryKey == category.key;
                    return ChoiceChip(
                      label: Text(
                        category.label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : AdminTheme.textDark,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AdminTheme.textDark,
                      backgroundColor: AdminTheme.surfaceIvory,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected ? AdminTheme.textDark : AdminTheme.border,
                        ),
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedCategoryKey = category.key);
                        }
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
                  child: CircularProgressIndicator(color: AdminTheme.textDark),
                ),
              )
                  : filtered.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      Icon(
                        _loadFailed
                            ? Icons.cloud_off
                            : Icons.inventory_2_outlined,
                        size: 48,
                        color: AdminTheme.mutedDark,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _loadFailed
                            ? 'Could not load inventory.'
                            : 'No inventory items found.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AdminTheme.textDark),
                      ),
                      if (_loadFailed) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Check the connection and try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AdminTheme.mutedDark),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.textDark,
                          ),
                          onPressed: _loadInventory,
                          child: const Text(
                            'Retry',
                            style: TextStyle(fontFamily: 'Inter', color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
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
                  final int stock = _asInt(item['stock_quantity'], 50);
                  final int threshold = _asInt(item['low_stock_threshold'], 10);
                  final String categoryName = _categoryNameFor(item);
                  final String? localImage = localMenuImageFor(name);

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
                      color: AdminTheme.surfaceIvory,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AdminTheme.border),
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
                            color: AdminTheme.warningBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: localImage != null && localImage.isNotEmpty
                                ? Image.asset(
                                    localImage,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.restaurant, color: AdminTheme.textDark),
                                  )
                                : const Icon(Icons.restaurant, color: AdminTheme.textDark),
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
                                        color: AdminTheme.textDark,
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
                                '$categoryName • ₱${price.toStringAsFixed(2)} • Threshold: $threshold',
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AdminTheme.mutedDark),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'On-hand: ',
                                        style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AdminTheme.mutedDark),
                                      ),
                                      Text(
                                        '$stock units',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          color: stock == 0 ? const Color(0xFFEF4444) : AdminTheme.textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AdminTheme.textDark,
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

class _StockCategoryFilter {
  const _StockCategoryFilter({required this.key, required this.label});

  final String key;
  final String label;
}