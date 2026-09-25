import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../services/shop_service.dart';
import '../theme/app_colors.dart';
import 'booking_form_page.dart';

class ShopDetailPage extends StatefulWidget {
  const ShopDetailPage({super.key, required this.shopId, this.shopPreview});

  final int shopId;
  final Shop? shopPreview;

  @override
  State<ShopDetailPage> createState() => _ShopDetailPageState();
}

class _ShopDetailPageState extends State<ShopDetailPage> {
  final ShopService _shopService = ShopService();
  late Future<Shop> _shopFuture;

  @override
  void initState() {
    super.initState();
    _shopFuture = _shopService.getShopDetail(widget.shopId);
  }

  void _openBookingForm(Shop shop, ShopServiceItem service) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookingFormPage(shop: shop, service: service)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: FutureBuilder<Shop>(
        future: _shopFuture,
        builder: (context, snapshot) {
          final shop = snapshot.data ?? widget.shopPreview;

          if (shop == null && snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (shop == null && snapshot.hasError) {
            return Center(
              child: Text('Failed to load shop: ${snapshot.error}', style: TextStyle(color: colors.textSecondary)),
            );
          }
          if (shop == null) {
            return const Center(child: Text('Shop not found.'));
          }

          final isDetailLoaded = snapshot.connectionState == ConnectionState.done && snapshot.hasData;
          final isShopOnline = shop.isOnline;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                expandedHeight: 172,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  title: Text(
                    shop.shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  background: Container(
                    color: colors.primary,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 56),
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.local_laundry_service_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShopStatusPill(isOnline: isShopOnline),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on_outlined, size: 16, color: colors.textSecondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              shop.address ?? 'Address not set',
                              style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                      if (shop.distanceKm != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.directions_walk_rounded, size: 16, color: colors.primary),
                            const SizedBox(width: 6),
                            Text(
                              '${shop.distanceKm!.toStringAsFixed(1)} km away',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.primary),
                            ),
                          ],
                        ),
                      ],
                      if (!isShopOnline) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.errorBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: colors.errorBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 18, color: colors.error),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'This shop is currently closed and not accepting new bookings right now. You can still browse their services.',
                                  style: TextStyle(fontSize: 12.5, color: colors.error, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Text(
                        'Available services',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      if (!isDetailLoaded)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (shop.services.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: colors.border),
                          ),
                          child: Text(
                            'This shop hasn\'t added any services yet.',
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        )
                      else
                        ...List.generate(shop.services.length, (index) {
                          final service = shop.services[index];
                          return Padding(
                            padding: EdgeInsets.only(bottom: index == shop.services.length - 1 ? 0 : 10),
                            child: _ServiceTile(
                              service: service,
                              isShopOnline: isShopOnline,
                              onBook: () => _openBookingForm(shop, service),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ShopStatusPill extends StatelessWidget {
  const _ShopStatusPill({required this.isOnline});
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color fg = isOnline ? colors.success : colors.neutral;
    final String label = isOnline ? 'Open now' : 'Currently closed';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.isShopOnline, required this.onBook});
  final ShopServiceItem service;
  final bool isShopOnline;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                const SizedBox(height: 3),
                Text(
                  '₱${service.price.toStringAsFixed(0)} / ${service.pricingUnit}',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: isShopOnline ? onBook : null,
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: colors.neutralBg,
              disabledForegroundColor: colors.neutral,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isShopOnline ? 'Book' : 'Closed'),
          ),
        ],
      ),
    );
  }
}