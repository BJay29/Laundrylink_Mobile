// ============================= main_nav_page.dart =============================
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

const Color _kNavyDeep = Color(0xFF0B1B4D);
const Color _kNavyMid = Color(0xFF152E7A);
const Color _kNavyGlow = Color(0xFF2946A3);
const Color _kAccentCyan = Color(0xFF38BDF8);
const Color _kAccentGold = Color(0xFFFACC15);

/// Ito na yung "totoong" header — bahagi na siya ng normal na layout flow
/// (Column: header sa taas, tapos Expanded body sa ibaba), hindi na siya
/// isang Positioned/Stack na "background shape" lang. Dahil dito, may
/// sarili na siyang espasyo — walang page content ang maaaring
/// mag-overlap o masapawan sa kanya, at ang border sa ibaba niya
/// (`_kHeaderBorder`) ay talagang gilid ng header, hindi guhit lang sa
/// ibabaw ng ibang bagay.
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

    // NOTE: pages ay hindi na tumatanggap ng `headerHeight`. Dahil ang
    // header ay hiwalay na row sa Column (hindi na Positioned background),
    // sariling espasyo na niya ang inuubos — ang body ay awtomatikong
    // nagsisimula sa ibaba ng header gamit ang Expanded, kaya normal na
    // top padding lang ang kailangan ng bawat page (tingnan sa
    // home_page.dart, history_page.dart, profile_page.dart).
    final pages = [
      HomePage(customer: customer),
      const BookingPage(),
      const HistoryPage(),
      ProfilePage(customer: customer),
    ];

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          _HeaderBackground(
            customer: customer,
            unreadCount: _unreadCount,
            onNotificationsTap: _openNotifications,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.03),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey<int>(_selectedIndex),
                child: pages[_selectedIndex],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _GlowFab(onTap: _openShopSelection),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _FloatingPillNav(
        selectedIndex: _selectedIndex,
        onSelect: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

/// Ang navy header ngayon — normal na widget sa loob ng Column, may
/// sarili itong laki (SafeArea + padding + content, hindi na fixed
/// `height` na ipinapasa galing sa labas). Idinagdag din ang tunay na
/// border sa ibaba (`Border.bottom`) — ito na mismo yung gilid/border na
/// hiniling mong ayusin: bahagi na siya ng header shape mismo, hindi
/// guhit lang na nakapatong sa ibabaw ng ibang layer.
class _HeaderBackground extends StatelessWidget {
  const _HeaderBackground({
    required this.customer,
    required this.unreadCount,
    required this.onNotificationsTap,
  });

  final Customer customer;
  final int unreadCount;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_kNavyDeep, _kNavyMid, _kNavyGlow],
            stops: [0.0, 0.55, 1.0],
          ),
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.14), width: 1),
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -30, right: -30, child: _orb(120, 0.10)),
            Positioned(top: 30, right: 60, child: _orb(50, 0.08)),
            Positioned(bottom: -50, left: -40, child: _orb(140, 0.08)),
            Positioned(top: 10, left: 90, child: _dot(6, 0.35)),
            Positioned(top: 60, left: 140, child: _dot(4, 0.3)),
            Positioned(top: 20, left: 200, child: _dot(5, 0.25)),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good day,',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white.withOpacity(0.65),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customer.fullName.split(' ').first,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: const TextSpan(
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic),
                              children: [
                                TextSpan(text: 'LAUNDRY', style: TextStyle(color: _kAccentCyan)),
                                TextSpan(text: 'LINK', style: TextStyle(color: _kAccentGold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _HeaderIconButton(
                      icon: Icons.notifications_none_rounded,
                      badgeCount: unreadCount,
                      onTap: onNotificationsTap,
                    ),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white.withOpacity(0.18),
                      child: Text(
                        customer.initials,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orb(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(opacity)),
      );

  Widget _dot(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(opacity)),
      );
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.badgeCount, required this.onTap});
  final IconData icon;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        shape: BoxShape.circle,
      ),
      child: Badge(
        isLabelVisible: badgeCount > 0,
        label: Text(badgeCount > 9 ? '9+' : '$badgeCount'),
        backgroundColor: const Color(0xFFEF4444),
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white, size: 21),
          tooltip: 'Notifications',
        ),
      ),
    );
  }
}

class _GlowFab extends StatelessWidget {
  const _GlowFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: _kAccentGold.withOpacity(0.45), blurRadius: 18, spreadRadius: 2),
        ],
      ),
      child: FloatingActionButton(
        onPressed: onTap,
        backgroundColor: _kAccentGold,
        foregroundColor: _kNavyDeep,
        elevation: 0,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}

class _FloatingPillNav extends StatelessWidget {
  const _FloatingPillNav({required this.selectedIndex, required this.onSelect});
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [_kNavyDeep, _kNavyMid, _kNavyGlow],
            stops: [0.0, 0.6, 1.0],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: _kNavyDeep.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
              selected: selectedIndex == 0,
              onTap: () => onSelect(0),
            ),
            _NavItem(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              label: 'Bookings',
              selected: selectedIndex == 1,
              onTap: () => onSelect(1),
            ),
            const SizedBox(width: 56),
            _NavItem(
              icon: Icons.history_outlined,
              activeIcon: Icons.history_rounded,
              label: 'History',
              selected: selectedIndex == 2,
              onTap: () => onSelect(2),
            ),
            _NavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
              selected: selectedIndex == 3,
              onTap: () => onSelect(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: selected ? Colors.white.withOpacity(0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  color: selected ? _kAccentCyan : Colors.white.withOpacity(0.55),
                  size: 22,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: selected ? Colors.white : Colors.white.withOpacity(0.55),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}