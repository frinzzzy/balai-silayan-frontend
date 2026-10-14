import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/user_session.dart';

class OrderProvider extends ChangeNotifier {
  bool _isLoading = false;
  List<dynamic> _unfinishedOrders = [];
  Map<String, dynamic>? _sessionBillData;

  bool get isLoading => _isLoading;
  List<dynamic> get unfinishedOrders => _unfinishedOrders;
  Map<String, dynamic>? get sessionBillData => _sessionBillData;
  bool get hasUnfinishedOrders => _unfinishedOrders.isNotEmpty;

  Future<void> loadUnfinishedOrders(int tableId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _unfinishedOrders = await ApiService.fetchUnfinishedOrders(tableId);
    } catch (e) {
      debugPrint('OrderProvider.loadUnfinishedOrders error: $e');
      _unfinishedOrders = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSessionBill({int? sessionId, int? tableId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _sessionBillData = await ApiService.fetchSessionBill(sessionId: sessionId, tableId: tableId);
    } catch (e) {
      debugPrint('OrderProvider.loadSessionBill error: $e');
      _sessionBillData = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearState() {
    _isLoading = false;
    _unfinishedOrders = [];
    _sessionBillData = null;
    notifyListeners();
  }
}
