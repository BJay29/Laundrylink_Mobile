import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../services/shop_service.dart';
import '../theme/app_colors.dart';
import '../widgets/illustrated_icon.dart';
import 'shop_detail_page.dart';

class ShopSelectionPage extends StatefulWidget {
  const ShopSelectionPage({super.key});

  @override
  State<ShopSelectionPage> createState() => _ShopSelectionPageState();
}

class _ShopSelectionPageState extends State<ShopSelectionPage> {
  final ShopService _shopService = ShopService();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<Shop>> _shopsFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _shopsFuture = _shopService.getShops();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _shopsFuture = _shopService.getShops();
    });
    await _shopsFuture;
  }

  List<Shop> _filterAndSort(List<Shop> shops) {
    final filtered = _query.isEmpty
        ? shops
        : shops.where((s) => s.shopName.toLowerCase().contains(_query)).toList();

    // Open shops muna, tapos pareho ng open-status ay pagsunud-sunurin
    // by distance — mas madaling makakita ng magagawang bookan kaysa
    // random na order.
    filtered.sort((a, b) {
      if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
      final da = a.distanceKm ?? double.infinity;
      final db = b.distanceKm ?? double.infinity;
      return da.compareTo(db);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        foregroundColor: colors.textPrimary,
        title: Text(
          'Select a shop',
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: colors.shadow, blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search shops',
                  hintStyle: TextStyle(color: colors.textMuted),
                  prefixIcon: Icon(Icons.search_rounded, color: colors.textSecondary),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.close_rounded, color: colors.textSecondary, size: 18),
                          onPressed: () => _searchController.clear(),
                        ),
                  filled: true,
                  fillColor: colors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.primary, width: 1.4),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Shop>>(
              future: _shopsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return IllustratedEmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: 'Failed to load shops',
                    message: '${snapshot.error}',
                    iconColor: colors.error,
                    iconBackgroundColor: colors.error,
                    action: TextButton(onPressed: _reload, child: const Text('Retry')),
                  );
                }

                final allShops = snapshot.data ?? [];
                if (allShops.isEmpty) {
                  return IllustratedEmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'No shops registered yet',
                    message: 'New shops will appear here once they join LaundryLink.',
                  );
                }

                final shops = _filterAndSort(allShops);
                if (shops.isEmpty) {
                  return IllustratedEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matches',
                    message: 'No shops found for "$_query". Try a different name.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    itemCount: shops.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _ShopListTile(shop: shops[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopListTile extends StatelessWidget {
  const _ShopListTile({required this.shop});
  final Shop shop;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ShopDetailPage(shopId: shop.id, shopPreview: shop)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border, width: 1),
          boxShadow: [BoxShadow(color: colors.shadow, blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            // Simplified from the previous gradient badge — a flat
            // tinted square (rounded, not a circle) so it reads as a
            // shop "tile" rather than a decorative avatar.
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: shop.isOnline
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [colors.chipBg, colors.primary.withOpacity(0.2)],
                      )
                    : null,
                color: shop.isOnline ? null : colors.neutralBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.local_laundry_service_rounded,
                color: shop.isOnline ? colors.primary : colors.neutral,
                size: 25,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    shop.address ?? 'Address not set',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _StatusBadge(isOnline: shop.isOnline),
                      if (shop.distanceKm != null) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(color: colors.chipBg, borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.directions_walk_rounded, size: 12, color: colors.primary),
                              const SizedBox(width: 3),
                              Text(
                                '${shop.distanceKm!.toStringAsFixed(1)} km',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colors.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colors.chipBg, shape: BoxShape.circle),
              child: Icon(Icons.chevron_right_rounded, size: 18, color: colors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isOnline});
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color fg = isOnline ? colors.success : colors.neutral;
    final Color bg = isOnline ? colors.successBg : colors.neutralBg;
    final String label = isOnline ? 'Open' : 'Closed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}