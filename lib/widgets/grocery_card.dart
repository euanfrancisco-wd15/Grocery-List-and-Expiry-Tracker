import 'package:flutter/material.dart';

import '../models/grocery.dart';
import '../theme/app_colors.dart';
import 'grocery_photo.dart';
import 'expiry_badge.dart';
import 'playful_entrance.dart';

class GroceryCard extends StatelessWidget {
  const GroceryCard({super.key, required this.grocery, this.onTap});

  final Grocery grocery;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _accentForCategory(grocery.category);
    final cardColor = grocery.isExpired
        ? AppColors.accentRed.withValues(alpha: .06)
        : grocery.isExpiringSoon
        ? AppColors.accentYellow.withValues(alpha: .11)
        : Color.lerp(Colors.white, accent, .07)!;

    return PlayfulEntrance(
      child: Card(
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: accent.withValues(alpha: .28)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: grocery.imagePath != null
                          ? GroceryPhoto(
                              path: grocery.imagePath!,
                              width: 54,
                              height: 54,
                              borderRadius: 15,
                            )
                          : Container(
                              width: 54,
                              height: 54,
                              color: accent.withValues(alpha: .16),
                              child: Center(
                                child: Text(
                                  _emojiForCategory(grocery.category),
                                  style: const TextStyle(fontSize: 27),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            grocery.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              grocery.category,
                              style: const TextStyle(
                                color: AppColors.darkGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ExpiryBadge(status: grocery.expiryStatus),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.scale_rounded,
                      label:
                          '${_formatQuantity(grocery.quantity)} ${grocery.unit}',
                      color: AppColors.accentBlue,
                    ),
                    _InfoChip(
                      icon: Icons.event_rounded,
                      label: grocery.isExpired
                          ? 'Expired ${_formatDate(grocery.expirationDate)} · ${grocery.daysRemaining.abs()}d ago'
                          : grocery.daysRemaining == 0
                          ? 'Expires today · ${_formatDate(grocery.expirationDate)}'
                          : 'Expires ${_formatDate(grocery.expirationDate)} · ${grocery.daysRemaining}d left',
                      color: grocery.isExpired
                          ? AppColors.accentRed
                          : AppColors.accentYellow,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  Color _accentForCategory(String category) => switch (category.toLowerCase()) {
    'fruits' || 'vegetables' || 'produce' => AppColors.primaryGreen,
    'dairy' => AppColors.accentBlue,
    'meat' || 'seafood' => AppColors.accentRed,
    'bakery' || 'snacks' => AppColors.accentYellow,
    _ => AppColors.primaryGreen,
  };

  String _emojiForCategory(String category) => switch (category.toLowerCase()) {
    'fruits' => '🍎',
    'vegetables' || 'produce' => '🥕',
    'dairy' => '🥛',
    'meat' => '🥩',
    'seafood' => '🐟',
    'bakery' => '🥖',
    'beverages' => '🧃',
    'snacks' => '🍿',
    'frozen' => '🧊',
    _ => '🛒',
  };
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.darkGreen),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.darkGreen,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
