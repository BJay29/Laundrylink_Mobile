import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Kulay ng mga bituin (puno). Iisang source para sa RatingBadge at
/// RatingCard/RatingStars, para pareho ang itsura sa buong app.
const Color kStarColor = Color(0xFFFBBF24);

/// NEW (Rating after order) — maliit na pill na nagpapakita ng
/// ★ 4.3 (12): average na bituin ng shop at kung ilang rating ang
/// pinagbasehan. Ginagamit sa Home (shop card), Shop Selection, at Shop
/// Detail para iisa lang ang itsura sa lahat ng lugar.
///
/// Walang ipinapakita (SizedBox.shrink) kapag wala pang rating ang shop
/// — averageRating null o ratingCount 0 — para hindi lumabas ang
/// "★ 0.0 (0)" sa mga bagong shop.
class RatingBadge extends StatelessWidget {
  const RatingBadge({
    super.key,
    required this.averageRating,
    required this.ratingCount,
  });

  final double? averageRating;
  final int ratingCount;

  /// Convenience: true kapag may ipapakita talaga. Ginagamit ng mga
  /// caller para hindi na magdagdag ng espasyo (SizedBox) kapag wala.
  static bool hasRating(double? averageRating, int ratingCount) =>
      averageRating != null && ratingCount > 0;

  @override
  Widget build(BuildContext context) {
    if (!hasRating(averageRating, ratingCount)) return const SizedBox.shrink();

    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kStarColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: kStarColor),
          const SizedBox(width: 3),
          Text(
            averageRating!.toStringAsFixed(1),
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: colors.textPrimary),
          ),
          const SizedBox(width: 3),
          Text(
            '($ratingCount)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}