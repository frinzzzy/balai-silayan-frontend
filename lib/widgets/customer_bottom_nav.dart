import 'package:flutter/material.dart';

/// Tabs ng consistent na customer bottom navigation.
enum CustomerNavTab { menu, cart, liveStatus, bill }

/// Intent flag para sa Cart tab mula sa ibang screen (Bill/Live Status).
///
/// Ang cart items ay naka-state sa MenuScreen, kaya kapag pinindot ang Cart
/// mula sa ibang screen, babalik muna tayo sa existing MenuScreen at doon
/// bubuksan ang cart para hindi mawala ang laman nito.
class MenuCartIntent {
  MenuCartIntent._();

  static final ValueNotifier<bool> openCart = ValueNotifier<bool>(false);

  static void requestOpen() {
    openCart.value = true;
  }

  static bool consume() {
    if (!openCart.value) return false;
    openCart.value = false;
    return true;
  }
}

/// Bottom navigation na laging apat ang items: Menu, Cart, Live Status, Bill.
///
/// Pinapanatili nitong pareho ang hitsura sa Menu, Bill, Bill Requested at
/// Live Status screens — ang [activeTab] lang ang nagbabago.
class CustomerBottomNav extends StatelessWidget {
  const CustomerBottomNav({
    super.key,
    required this.activeTab,
    required this.onMenu,
    required this.onCart,
    required this.onLiveStatus,
    required this.onBill,
  });

  final CustomerNavTab activeTab;
  final VoidCallback onMenu;
  final VoidCallback onCart;
  final VoidCallback onLiveStatus;
  final VoidCallback onBill;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDFA),
        border: Border(top: BorderSide(color: Color(0xFFE5DFD3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            Icons.restaurant,
            'Menu',
            isActive: activeTab == CustomerNavTab.menu,
            onTap: onMenu,
          ),
          _buildNavItem(
            Icons.shopping_bag_outlined,
            'Cart',
            isActive: activeTab == CustomerNavTab.cart,
            onTap: onCart,
          ),
          _buildNavItem(
            Icons.track_changes,
            'Live Status',
            isActive: activeTab == CustomerNavTab.liveStatus,
            onTap: onLiveStatus,
          ),
          _buildNavItem(
            Icons.account_balance_wallet_outlined,
            'Bill',
            isActive: activeTab == CustomerNavTab.bill,
            onTap: onBill,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label, {
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: isActive ? const Color(0xFF203F35) : const Color(0xFF788078),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive
                  ? const Color(0xFF203F35)
                  : const Color(0xFF788078),
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 2),
            Container(
              width: 16,
              height: 2,
              decoration: BoxDecoration(
                color: const Color(0xFFA47C3D),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
