import 'package:flutter/material.dart';
import 'auth_screen.dart';
import 'orders_screen.dart';
import 'reservations_screen.dart';
import 'assistance_screen.dart';

class HomeHubScreen extends StatefulWidget {
  const HomeHubScreen({super.key});

  @override
  State<HomeHubScreen> createState() => _HomeHubScreenState();
}

class _HomeHubScreenState extends State<HomeHubScreen> {
  int _currentIndex = 0;
  String? _authToken;
  String _currentUserName = "Guest User";
  final List<Map<String, dynamic>> _cartItems = [];

  void _onLoginSuccess(String token, String name) {
    setState(() {
      _authToken = token;
      _currentUserName = name;
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      AuthScreen(onLoginSuccess: _onLoginSuccess),
      OrdersScreen(cartItems: _cartItems, authToken: _authToken),
      const ReservationsScreen(),
      const AssistanceScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Secure Access Gateway' : 'System Hub: $_currentUserName'),
        backgroundColor: const Color(0xFF0F0F1D),
        elevation: 0,
        actions: _authToken != null ? [
          const Icon(Icons.verified_user, color: Color(0xFF00CEC9)),
          const SizedBox(width: 16),
        ] : null,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF0F0F1D),
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.white30,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.vpn_key_outlined), label: 'Auth'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.desktop_mac_outlined), label: 'Assets'),
          BottomNavigationBarItem(icon: Icon(Icons.forum_outlined), label: 'Assistance'),
        ],
      ),
    );
  }
}
