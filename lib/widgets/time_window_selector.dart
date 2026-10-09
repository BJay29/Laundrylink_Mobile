import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// NEW (Flexible Booking feature) — reusable chip row para sa
/// pagpili ng time window: "morning" | "afternoon" | "evening" |
/// "anytime" | null (walang window, exact time na lang ang ginagamit).
/// Ginagamit ito PAREHO sa booking_form_page.dart (paggawa ng bagong
/// booking) at sa edit_booking_page.dart (pag-edit ng existing booking)
/// — kaya nasa sariling file ito, hindi private class sa loob ng isang
/// page lang.
///
/// Tumatapak muli sa parehong chip ay nagki-clear nito (nagiging null).
class TimeWindowSelector extends StatelessWidget {
  const TimeWindowSelector({super.key, required this.selected, required this.onChanged});

  /// null | 'morning' | 'afternoon' | 'evening' | 'anytime'
  final String? selected;
  final ValueChanged<String?> onChanged;

  static const _options = [
    ('morning', 'Morning', Icons.wb_twilight_rounded),
    ('afternoon', 'Afternoon', Icons.wb_sunny_rounded),
    ('evening', 'Evening', Icons.nights_stay_rounded),
    ('anytime', 'Anytime', Icons.all_inclusive_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _options.map((option) {
        final (value, label, icon) = option;
        final isSelected = selected == value;
        return InkWell(
          onTap: () => onChanged(isSelected ? null : value),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? colors.chipBg : colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? colors.primary : colors.border, width: isSelected ? 1.4 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: isSelected ? colors.primary : colors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? colors.primary : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Display label ng isang window key — ginagamit sa order_tracking_page
/// at ibang lugar na nagpapakita lang (hindi nag-e-edit) ng window.
/// Nagbabalik ng null kung walang tumutugmang key, para sa caller na
/// mag-decide kung ano ang ipapakita bilang fallback.
String? timeWindowLabel(String? key) {
  switch (key) {
    case 'morning':
      return 'Morning';
    case 'afternoon':
      return 'Afternoon';
    case 'evening':
      return 'Evening';
    case 'anytime':
      return 'Anytime';
    default:
      return null;
  }
}