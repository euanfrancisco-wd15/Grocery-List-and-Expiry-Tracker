import 'package:flutter/material.dart';

import '../models/grocery.dart';

class ExpiryBadge extends StatelessWidget {
  const ExpiryBadge({super.key, required this.status});

  final ExpiryStatus status;

  @override
  Widget build(BuildContext context) {
    final badge = switch (status) {
      ExpiryStatus.safe => _BadgeStyle(
        label: 'Safe',
        foreground: const Color(0xFF047857),
        background: const Color(0xFFD1FAE5),
      ),
      ExpiryStatus.expiringSoon => _BadgeStyle(
        label: 'Expiring Soon',
        foreground: const Color(0xFFB45309),
        background: const Color(0xFFFEF3C7),
      ),
      ExpiryStatus.expiresToday => _BadgeStyle(
        label: 'Expires Today',
        foreground: const Color(0xFFC2410C),
        background: const Color(0xFFFFEDD5),
      ),
      ExpiryStatus.expired => _BadgeStyle(
        label: 'Expired',
        foreground: const Color(0xFFB91C1C),
        background: const Color(0xFFFEE2E2),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badge.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        badge.label,
        style: TextStyle(
          color: badge.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BadgeStyle {
  const _BadgeStyle({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;
}
