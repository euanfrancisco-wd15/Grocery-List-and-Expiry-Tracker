import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/grocery.dart';
import '../services/grocery_service.dart';
import '../services/device_notification_service.dart';
import '../services/monthly_budget_service.dart';
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
    required this.onOpenReports,
    required this.onOpenInventory,
    required this.onOpenSettings,
    required this.onOpenNotifications,
    required this.onOpenExpiring,
    required this.onOpenExpired,
  });

  final User user;
  final GroceryService groceryService;
  final VoidCallback onAddGrocery;
  final ValueChanged<Grocery> onOpenGrocery;
  final VoidCallback onOpenReports;
  final VoidCallback onOpenInventory;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenExpiring;
  final VoidCallback onOpenExpired;
  static final _deviceNotificationService = DeviceNotificationService.instance;

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
              userId: user.uid,
              onOpenSettings: onOpenSettings,
              onOpenNotifications: onOpenNotifications,
              child: const _DashboardErrorState(),
            );
          }

          final groceries = snapshot.data ?? [];
          if (snapshot.hasData) {
            unawaited(
              _deviceNotificationService.syncForUser(
                userId: user.uid,
                groceries: groceries,
              ),
            );
          }
          final expiringSoon = groceries
              .where((grocery) => grocery.isExpiringSoon)
              .toList();
          final expiredCount = groceries
              .where((grocery) => grocery.isExpired)
              .length;

          return _DashboardFrame(
            displayName: displayName,
            userId: user.uid,
            onOpenSettings: onOpenSettings,
            onOpenNotifications: onOpenNotifications,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _QuickActions(
                  onAdd: onAddGrocery,
                  onInventory: onOpenInventory,
                  onReports: onOpenReports,
                  onSettings: onOpenSettings,
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 760;
                    final cards = [
                      SummaryCard(
                        title: 'Total Items',
                        value: groceries.length,
                        icon: Icons.inventory_2_rounded,
                        color: AppColors.primaryGreen,
                        onTap: onOpenInventory,
                      ),
                      SummaryCard(
                        title: 'Expiring Soon',
                        value: expiringSoon.length,
                        icon: Icons.schedule_rounded,
                        color: const Color(0xFFF59E0B),
                        onTap: onOpenExpiring,
                      ),
                      SummaryCard(
                        title: 'Expired',
                        value: expiredCount,
                        icon: Icons.warning_rounded,
                        color: const Color(0xFFEF4444),
                        onTap: onOpenExpired,
                      ),
                    ];

                    if (isWide) {
                      return Row(
                        children: [
                          for (var index = 0; index < cards.length; index++)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: index < cards.length - 1 ? 12 : 0,
                                ),
                                child: cards[index],
                              ),
                            ),
                        ],
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
                const SizedBox(height: 14),
                _BudgetReport(userId: user.uid),
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
                    TextButton.icon(
                      onPressed: onOpenInventory,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('View inventory'),
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

class _BudgetReport extends StatelessWidget {
  const _BudgetReport({required this.userId});
  final String userId;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots(),
    builder: (context, snapshot) {
      final profile = snapshot.data?.data() ?? {};
      final now = DateTime.now();
      final budget = MonthlyBudgetService.budgetFromProfile(profile, now);
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('expenses')
            .snapshots(),
        builder: (context, expenseSnapshot) {
          final spent = (expenseSnapshot.data?.docs ?? []).fold<double>(0, (
            total,
            doc,
          ) {
            final data = doc.data();
            final rawDate = data['purchaseDate'];
            final date = rawDate is Timestamp
                ? rawDate.toDate()
                : rawDate as DateTime?;
            if (date == null ||
                date.year != now.year ||
                date.month != now.month) {
              return total;
            }
            return total + ((data['amount'] as num?)?.toDouble() ?? 0);
          });
          final ratio = budget <= 0 ? 0.0 : (spent / budget).clamp(0.0, 1.0);
          final remaining = budget - spent;
          final percent = budget <= 0 ? 0 : (spent / budget * 100).round();
          final stateColor = percent >= 100
              ? const Color(0xFFCC7F7A)
              : percent >= 90
              ? const Color(0xFFD99A59)
              : percent >= 70
              ? const Color(0xFFD5B75C)
              : AppColors.primaryGreen;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Budget · ${MonthlyBudgetService.monthKey(now)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          _editDashboardBudget(context, userId, now, budget),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(budget <= 0 ? 'Set Budget' : 'Edit'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    budget <= 0
                        ? 'No monthly budget set yet.'
                        : 'Budget ₱${budget.toStringAsFixed(2)}  ·  Spent ₱${spent.toStringAsFixed(2)}  ·  Remaining ₱${remaining.toStringAsFixed(2)}',
                  ),
                  if (budget > 0) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                      color: stateColor,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      spent > budget
                          ? 'Budget exceeded by ₱${(spent - budget).toStringAsFixed(2)} · $percent% used'
                          : '$percent% used this month',
                      style: TextStyle(
                        color: stateColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> _editDashboardBudget(
  BuildContext context,
  String userId,
  DateTime month,
  double current,
) async {
  final controller = TextEditingController(
    text: current > 0 ? current.toStringAsFixed(2) : '',
  );
  final formKey = GlobalKey<FormState>();
  try {
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Budget for ${MonthlyBudgetService.monthKey(month)}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monthly budget',
              prefixText: '₱ ',
            ),
            validator: (value) {
              final amount = double.tryParse((value ?? '').trim());
              return amount == null || !amount.isFinite || amount <= 0
                  ? 'Enter an amount greater than zero.'
                  : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(
                  dialogContext,
                  double.parse(controller.text.trim()),
                );
              }
            },
            child: const Text('Save Budget'),
          ),
        ],
      ),
    );
    if (amount != null) {
      await MonthlyBudgetService().saveBudget(
        userId: userId,
        month: month,
        amount: amount,
      );
      await DeviceNotificationService.instance.evaluateBudgetAfterExpense(
        userId: userId,
        month: month,
      );
    }
  } finally {
    controller.dispose();
  }
}

class _DashboardFrame extends StatelessWidget {
  const _DashboardFrame({
    required this.displayName,
    required this.userId,
    required this.child,
    required this.onOpenSettings,
    required this.onOpenNotifications,
  });

  final String displayName;
  final String userId;
  final Widget child;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    final profile = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: profile,
      builder: (context, profileSnapshot) {
        final saved = profileSnapshot.data?.data()?['username'] as String?;
        final name = saved?.trim().isNotEmpty == true
            ? saved!.trim()
            : displayName;
        return LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 420 ? 16.0 : 24.0;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    20,
                    horizontalPadding,
                    28,
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryGreen, AppColors.darkGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.darkGreen.withValues(alpha: .16),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.accentYellow,
                            foregroundColor: AppColors.darkGreen,
                            child: Text(
                              name.isEmpty ? 'G' : name[0].toUpperCase(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello, $name!',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                ),
                                Text(
                                  'Good food, better days!',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .88),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(userId)
                                .collection('notifications')
                                .where('read', isEqualTo: false)
                                .snapshots(),
                            builder: (context, snapshot) {
                              final unread = snapshot.data?.docs.length ?? 0;
                              return IconButton(
                                onPressed: onOpenNotifications,
                                tooltip: 'Notifications',
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.accentYellow,
                                  foregroundColor: AppColors.darkGreen,
                                ),
                                icon: Badge(
                                  isLabelVisible: unread > 0,
                                  label: Text(unread > 99 ? '99+' : '$unread'),
                                  child: const Icon(
                                    Icons.notifications_none_rounded,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    child,
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onAdd,
    required this.onInventory,
    required this.onReports,
    required this.onSettings,
  });
  final VoidCallback onAdd, onInventory, onReports, onSettings;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Add Grocery'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.darkGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          _ActionChip(
            icon: Icons.inventory_2_outlined,
            label: 'Inventory',
            onTap: onInventory,
          ),
          _ActionChip(
            icon: Icons.bar_chart_rounded,
            label: 'Reports',
            onTap: onReports,
          ),
          _ActionChip(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: onSettings,
          ),
        ],
      ),
    ],
  );
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, size: 18, color: AppColors.darkGreen),
    label: Text(label),
    backgroundColor: Colors.white,
    side: const BorderSide(color: AppColors.borderGreen),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    onPressed: onTap,
  );
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
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                color: AppColors.lightGreenBackground,
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.all(5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/gropanda_logo.png',
                  fit: BoxFit.cover,
                  semanticLabel: 'GroPanda mascot with a grocery basket',
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('🍎   🥕   🥦', style: TextStyle(fontSize: 22)),
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
