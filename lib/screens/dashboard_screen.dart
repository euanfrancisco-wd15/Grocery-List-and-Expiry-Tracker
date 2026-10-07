import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/grocery.dart';
import '../services/grocery_service.dart';
import '../theme/app_colors.dart';
import '../widgets/grocery_card.dart';
import '../widgets/summary_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.user,
    required this.groceryService,
    required this.onAddGrocery,
    required this.onOpenGrocery,
  });

  final User user;
  final GroceryService groceryService;
  final VoidCallback onAddGrocery;
  final ValueChanged<Grocery> onOpenGrocery;

  @override
  Widget build(BuildContext context) {
    final displayName =
        user.displayName ?? user.email?.split('@').first ?? 'shopper';

    return SafeArea(
      child: StreamBuilder<List<Grocery>>(
        stream: groceryService.watchGroceries(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            );
          }

          if (snapshot.hasError) {
            return _DashboardFrame(
              displayName: displayName,
              child: const _DashboardErrorState(),
            );
          }

          final groceries = snapshot.data ?? [];
          final expiringSoon = groceries
              .where((grocery) => grocery.isExpiringSoon)
              .toList();
          final expiredCount = groceries
              .where((grocery) => grocery.isExpired)
              .length;

          return _DashboardFrame(
            displayName: displayName,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 620;
                    final cards = [
                      SummaryCard(
                        title: 'Total Items',
                        value: groceries.length,
                        icon: Icons.inventory_2_rounded,
                        color: AppColors.primaryGreen,
                      ),
                      SummaryCard(
                        title: 'Expiring Soon',
                        value: expiringSoon.length,
                        icon: Icons.schedule_rounded,
                        color: const Color(0xFFF59E0B),
                      ),
                      SummaryCard(
                        title: 'Expired',
                        value: expiredCount,
                        icon: Icons.warning_rounded,
                        color: const Color(0xFFEF4444),
                      ),
                    ];

                    if (isWide) {
                      return Row(
                        children: cards
                            .map(
                              (card) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: card,
                                ),
                              ),
                            )
                            .toList(),
                      );
                    }

                    return Column(
                      children: cards
                          .map(
                            (card) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: card,
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Expiring Soon',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: onAddGrocery,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Grocery'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (expiringSoon.isEmpty)
                  const _NoExpiringItemsState()
                else
                  ...expiringSoon
                      .take(4)
                      .map(
                        (grocery) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GroceryCard(
                            grocery: grocery,
                            onTap: () => onOpenGrocery(grocery),
                          ),
                        ),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardFrame extends StatelessWidget {
  const _DashboardFrame({required this.displayName, required this.child});

  final String displayName;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      children: [
        Text(
          'Hello, $displayName',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Here's your grocery overview.",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
        ),
        const SizedBox(height: 24),
        child,
      ],
    );
  }
}

class _NoExpiringItemsState extends StatelessWidget {
  const _NoExpiringItemsState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.lightGreenBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: AppColors.primaryGreen,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No groceries are expiring soon.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your fresh items are looking good.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Icon(Icons.cloud_off_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'We could not load your grocery overview. Please check your connection and try again.',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
