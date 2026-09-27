import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../theme/app_colors.dart';

/// Sliding "Promos for you" carousel for the Home page — one card per
/// shop that currently has at least one active promo code
/// (shop.activePromos.isNotEmpty; filtering happens in the caller).
///
/// Uses a PageView with a fractional viewport so the next card visibly
/// peeks in from the edge (the "sliding" effect requested), plus a
/// scale/opacity fade on the non-focused cards driven by the page
/// controller's live scroll offset, and a row of dot indicators below
/// that track the current page.
///
/// Deliberately takes an [onShopTap] callback rather than importing
/// ShopDetailPage directly, so this widget doesn't need to know about
/// navigation/routing — the Home page decides what tapping a promo
/// card actually does.
class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key, required this.shops, required this.onShopTap});

  /// Shops to show, each expected to have a non-empty `activePromos`.
  final List<Shop> shops;
  final ValueChanged<Shop> onShopTap;

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  late final PageController _controller;
  double _page = 0;

  // A small rotating gradient palette so consecutive promo cards don't
  // all look identical — cycles by index, not tied to any particular
  // shop, so it stays stable across rebuilds.
  static const List<List<Color>> _palettes = [
    [Color(0xFFFF6B6B), Color(0xFFFFA36B)],
    [Color(0xFF7C3AED), Color(0xFF38BDF8)],
    [Color(0xFF0EA5A5), Color(0xFF34D399)],
    [Color(0xFFF59E0B), Color(0xFFEF4444)],
  ];

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.86);
    _controller.addListener(() {
      if (!mounted) return;
      setState(() => _page = _controller.page ?? 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shops = widget.shops;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 158,
          child: PageView.builder(
            controller: _controller,
            itemCount: shops.length,
            padEnds: false,
            itemBuilder: (context, index) {
              final delta = (_page - index).clamp(-1.0, 1.0).abs();
              final scale = 1 - (delta * 0.08);
              final opacity = 1 - (delta * 0.35);

              return Padding(
                padding: EdgeInsets.only(right: index == shops.length - 1 ? 20 : 12, left: index == 0 ? 0 : 0),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: _PromoCard(
                      shop: shops[index],
                      colors: _palettes[index % _palettes.length],
                      onTap: () => widget.onShopTap(shops[index]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (shops.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            children: List.generate(shops.length, (index) {
              final isActive = (_page.round() == index);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 6),
                width: isActive ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? context.colors.primary : context.colors.border,
                  borderRadius: BorderRadius.circular(20),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.shop, required this.colors, required this.onTap});

  final Shop shop;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final promo = shop.activePromos.first;
    final extraCount = shop.activePromos.length - 1;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: colors.last.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 10)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(top: -26, right: -18, child: _bubble(80, Colors.white.withOpacity(0.12))),
            Positioned(bottom: -34, left: -20, child: _bubble(64, Colors.white.withOpacity(0.1))),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_laundry_service_rounded, color: Colors.white, size: 19),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        promo.label,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: colors.last),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  shop.shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.sell_rounded, size: 13, color: Colors.white.withOpacity(0.85)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        extraCount > 0 ? 'Use code ${promo.code} (+$extraCount more)' : 'Use code ${promo.code}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      'Tap to view offer',
                      style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(double size, Color color) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}