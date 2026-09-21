import 'dart:async';

import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../services/customer_session.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import 'booking_page.dart';
import 'history_page.dart';
import 'home_page.dart';
import 'notification_page.dart';
import 'profile_page.dart';
import 'shop_selection_page.dart';

class MainNavPage extends StatefulWidget {
  const MainNavPage({super.key, this.customer});
  final Customer? customer;

  @override
  State<MainNavPage> createState() => _MainNavPageState();
}

class _MainNavPageState extends State<MainNavPage> {
  int _selectedIndex = 0;

  final NotificationService _notificationService = NotificationService();
  int _unreadCount = 0;
  Timer? _unreadPollTimer;

  @override
  void initState() {
    super.initState();
    CustomerSession.instance.addListener(_onSessionChanged);

    _loadUnreadCount();
    _unreadPollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadUnreadCount());
  }

  @override
  void dispose() {
    CustomerSession.instance.removeListener(_onSessionChanged);
    _unreadPollTimer?.cancel();
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _notificationService.getUnreadCount();
      if (!mounted) return;
      setState(() => _unreadCount = count);
    } catch (_) {
      // Silent fail — background poll lang ito.
    }
  }

  Customer get _resolvedCustomer =>
      widget.customer ?? CustomerSession.instance.customer ?? Customer.demo;

  String get _title => ['Home', 'My bookings', 'History', 'Profile'][_selectedIndex];

  void _openShopSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ShopSelectionPage()),
    );
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    ).then((_) => _loadUnreadCount());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final customer = _resolvedCustomer;

    final pages = [
      HomePage(customer: customer),
      const BookingPage(),
      const HistoryPage(),
      ProfilePage(customer: customer),
    ];
    return Scaffold(
      backgroundColor: colors.background,
      extendBody: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: AppBar(
          backgroundColor: colors.surface,
          surfaceTintColor: colors.surface,
          elevation: 0,
          automaticallyImplyLeading: false,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          toolbarHeight: 64,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic),
                    children: [
                      TextSpan(text: 'LAUNDRY', style: TextStyle(color: Color(0xFF0EA5E9))),
                      TextSpan(text: 'LINK', style: TextStyle(color: Color(0xFF16A34A))),
                    ],
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(customer.fullName, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: colors.textPrimary)),
                    Text(customer.mobileNumber, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                  ],
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 17,
                  backgroundColor: colors.primary,
                  child: Text(
                    customer.initials,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  decoration: BoxDecoration(color: colors.chipBg, shape: BoxShape.circle),
                  child: Badge(
                    isLabelVisible: _unreadCount > 0,
                    label: Text(_unreadCount > 9 ? '9+' : '$_unreadCount'),
                    backgroundColor: colors.error,
                    child: IconButton(
                      onPressed: _openNotifications,
                      icon: Icon(Icons.notifications_none_rounded, color: colors.primary, size: 20),
                      tooltip: 'Notifications',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: pages[_selectedIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: _openShopSelection,
        backgroundColor: const Color(0xFFFACC15),
        foregroundColor: const Color(0xFF075985),
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        child: BottomAppBar(
          // UPDATED — dating 62, binawasan pa papuntang 54 (mas manipis
          // na blue bar sa ilalim).
          height: 54,
          padding: EdgeInsets.zero,
          color: const Color(0xFF0EA5E9),
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          child: Row(children: [
            _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home', selected: _selectedIndex == 0, onTap: () => setState(() => _selectedIndex = 0)),
            _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'Bookings', selected: _selectedIndex == 1, onTap: () => setState(() => _selectedIndex = 1)),
            const SizedBox(width: 56),
            _NavItem(icon: Icons.history_outlined, activeIcon: Icons.history_rounded, label: 'History', selected: _selectedIndex == 2, onTap: () => setState(() => _selectedIndex = 2)),
            _NavItem(icon: Icons.person_outline, activeIcon: Icons.person_rounded, label: 'Profile', selected: _selectedIndex == 3, onTap: () => setState(() => _selectedIndex = 3)),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, color: selected ? Colors.white : const Color(0xFFBAE6FD), size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: selected ? Colors.white : const Color(0xFFBAE6FD),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
}