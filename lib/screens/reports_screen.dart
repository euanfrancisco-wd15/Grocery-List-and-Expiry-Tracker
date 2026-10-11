import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/monthly_budget_service.dart';
import '../services/expense_service.dart';
import '../services/device_notification_service.dart';
import '../models/grocery_options.dart';
import '../theme/app_colors.dart';
import '../widgets/section_header.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.userId, this.initialMonth});

  final String userId;
  final DateTime? initialMonth;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTime _month = DateTime(
    widget.initialMonth?.year ?? DateTime.now().year,
    widget.initialMonth?.month ?? DateTime.now().month,
  );
  final _budgetService = MonthlyBudgetService();
  final _expenseService = ExpenseService();
  bool _weeklyView = false;

  @override
  void didUpdateWidget(covariant ReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMonth != widget.initialMonth &&
        widget.initialMonth != null) {
      _month = DateTime(widget.initialMonth!.year, widget.initialMonth!.month);
    }
  }

  void _changeMonth(int offset) {
    setState(() => _month = DateTime(_month.year, _month.month + offset));
  }

  Future<void> _editExpense({
    QueryDocumentSnapshot<Map<String, dynamic>>? expense,
  }) async {
    final data = expense?.data() ?? const <String, dynamic>{};
    final description = TextEditingController(
      text: data['description'] as String? ?? data['name'] as String? ?? '',
    );
    final amount = TextEditingController(
      text: (data['amount'] as num?)?.toStringAsFixed(2) ?? '',
    );
    final formKey = GlobalKey<FormState>();
    var category =
        data['category'] as String? ?? GroceryOptions.categories.first;
    final rawDate = data['purchaseDate'];
    var date = rawDate is Timestamp ? rawDate.toDate() : DateTime.now();
    try {
      final result = await showDialog<Map<String, Object>?>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(expense == null ? 'Add Expense' : 'Edit Expense'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: description,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Add a description.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₱ ',
                      ),
                      validator: (value) {
                        final parsed = double.tryParse((value ?? '').trim());
                        return parsed == null || !parsed.isFinite || parsed <= 0
                            ? 'Enter an amount greater than zero.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: GroceryOptions.categories.contains(category)
                          ? category
                          : 'Other',
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: GroceryOptions.categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => category = value);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Expense date'),
                      subtitle: Text('${date.day}/${date.month}/${date.year}'),
                      trailing: const Icon(Icons.calendar_month_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setDialogState(() => date = picked);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(dialogContext, {
                    'description': description.text.trim(),
                    'amount': double.parse(amount.text.trim()),
                    'category': category,
                    'date': date,
                  });
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
      if (result == null) return;
      await _expenseService.saveManualExpense(
        userId: widget.userId,
        expenseId: expense?.id,
        description: result['description']! as String,
        amount: result['amount']! as double,
        category: result['category']! as String,
        date: result['date']! as DateTime,
      );
      await DeviceNotificationService.instance.evaluateBudgetAfterExpense(
        userId: widget.userId,
        month: _month,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Expense saved.')));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message
                  : 'Could not save the expense. Check your connection and try again.',
            ),
          ),
        );
      }
    } finally {
      description.dispose();
      amount.dispose();
    }
  }

  Future<void> _deleteExpense(
    QueryDocumentSnapshot<Map<String, dynamic>> expense,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text('This expense will be removed from your reports.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _expenseService.deleteManualExpense(
        userId: widget.userId,
        expenseId: expense.id,
      );
      await DeviceNotificationService.instance.evaluateBudgetAfterExpense(
        userId: widget.userId,
        month: _month,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Expense deleted.')));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message
                  : 'Could not delete the expense. Check your connection and try again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _setSelectedMonthBudget(
    BuildContext context, {
    required double current,
  }) async {
    final controller = TextEditingController(
      text: current > 0 ? current.toStringAsFixed(2) : '',
    );
    final formKey = GlobalKey<FormState>();
    try {
      final amount = await showDialog<double>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Budget for ${_monthName(_month.month)} ${_month.year}'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monthly budget',
                prefixText: '₱ ',
              ),
              validator: (value) {
                final parsed = double.tryParse((value ?? '').trim());
                return parsed == null || !parsed.isFinite || parsed <= 0
                    ? 'Enter an amount greater than zero.'
                    : null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(context, double.parse(controller.text.trim()));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (amount != null) {
        await _budgetService.saveBudget(
          userId: widget.userId,
          month: _month,
          amount: amount,
        );
        await DeviceNotificationService.instance.evaluateBudgetAfterExpense(
          userId: widget.userId,
          month: _month,
        );
      }
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId);
    return SafeArea(
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: user.snapshots(),
        builder: (context, profileSnapshot) {
          final profile = profileSnapshot.data?.data() ?? <String, dynamic>{};
          final budget = MonthlyBudgetService.budgetFromProfile(
            profile,
            _month,
          );
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _budgetService.watchExpensesForMonth(
              userId: widget.userId,
              month: _month,
            ),
            builder: (context, expenseSnapshot) {
              if (expenseSnapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Your reports could not be loaded. Check your connection and try again.',
                    ),
                  ),
                );
              }
              if (expenseSnapshot.connectionState == ConnectionState.waiting &&
                  !expenseSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final expenseDocs = [...?expenseSnapshot.data?.docs]
                ..sort(
                  (a, b) =>
                      _expenseDate(a.data()).compareTo(_expenseDate(b.data())),
                );
              final expenses = expenseDocs.map((doc) => doc.data()).toList();
              final spent = MonthlyBudgetService.sumExpenses(expenses);
              final remaining = budget - spent;
              final percent = budget <= 0 ? 0.0 : spent / budget * 100;
              final progress = (percent / 100).clamp(0.0, 1.0);
              final color = _statusColor(percent);
              final byCategory = <String, double>{};
              final weekly = List<double>.filled(5, 0);
              for (final expense in expenses) {
                final category = expense['category'] as String? ?? 'Other';
                final amount = (expense['amount'] as num?)?.toDouble() ?? 0;
                byCategory[category] = (byCategory[category] ?? 0) + amount;
                final rawDate = expense['purchaseDate'];
                final date = rawDate is Timestamp
                    ? rawDate.toDate()
                    : rawDate is DateTime
                    ? rawDate
                    : null;
                if (date != null) {
                  final week = ((date.day - 1) ~/ 7).clamp(0, 4);
                  weekly[week] += amount;
                }
              }
              final maxWeek = weekly.fold<double>(0, (a, b) => a > b ? a : b);
              final categories = byCategory.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              return ListView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                children: [
                  const SectionHeader(
                    title: 'Reports',
                    subtitle: 'Your monthly grocery spending.',
                    icon: Icons.bar_chart_rounded,
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Previous month',
                            onPressed: () => _changeMonth(-1),
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: Text(
                              '${_monthName(_month.month)} ${_month.year}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Next month',
                            onPressed: () => _changeMonth(1),
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monthly Budget',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (budget <= 0) ...[
                            const SizedBox(height: 8),
                            const Text('No monthly budget set'),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _setSelectedMonthBudget(
                                  context,
                                  current: budget,
                                ),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Set Monthly Budget'),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 10),
                            Text(
                              '₱${budget.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.darkGreen,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _Metric(
                                    label: 'Spent this month',
                                    value: '₱${spent.toStringAsFixed(2)}',
                                  ),
                                ),
                                Expanded(
                                  child: _Metric(
                                    label: 'Remaining',
                                    value:
                                        '${remaining < 0 ? '−' : ''}₱${remaining.abs().toStringAsFixed(2)}',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 10,
                                color: color,
                                backgroundColor: const Color(0xFFE8EFE5),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              percent > 100
                                  ? 'Budget exceeded by ₱${(spent - budget).toStringAsFixed(2)} · ${percent.round()}% used'
                                  : '${percent.round()}% used · ${_budgetStatus(percent)}',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Monthly')),
                      ButtonSegment(value: true, label: Text('Weekly')),
                    ],
                    selected: {_weeklyView},
                    onSelectionChanged: (value) =>
                        setState(() => _weeklyView = value.first),
                  ),
                  const SizedBox(height: 14),
                  if (!_weeklyView)
                    _CategoryDonutCard(categories: categories, total: spent)
                  else
                    _ChartCard(
                      title: 'Weekly spending · 7-day periods in this month',
                      emptyMessage:
                          'Weekly totals will appear when you add expenses.',
                      children: List.generate(
                        5,
                        (index) => _PastelBar(
                          label: _weeklyRangeLabel(index),
                          value: weekly[index],
                          maximum: maxWeek,
                          amountLabel: '₱${weekly[index].toStringAsFixed(2)}',
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Recent expenses',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _editExpense(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (expenseDocs.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No expenses recorded for this month yet.'),
                      ),
                    ),
                  ...expenseDocs.reversed.take(30).map((doc) {
                    final item = doc.data();
                    final isGrocery = item['groceryId'] != null;
                    final dateValue = item['purchaseDate'];
                    final date = dateValue is Timestamp
                        ? dateValue.toDate()
                        : DateTime.now();
                    final title =
                        item['description'] as String? ??
                        item['name'] as String? ??
                        'Expense';
                    final value = (item['amount'] as num?)?.toDouble() ?? 0;
                    final category = (item['category'] as String? ?? 'Other')
                        .toLowerCase();
                    final tint = switch (category) {
                      'dairy' => AppColors.accentBlue,
                      'meat' || 'seafood' => AppColors.accentRed,
                      'fruits' ||
                      'vegetables' ||
                      'produce' => AppColors.primaryGreen,
                      _ => AppColors.accentYellow,
                    };
                    return Card(
                      color: Color.lerp(Colors.white, tint, .07)!,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: tint.withValues(alpha: .22),
                          child: const Icon(
                            Icons.receipt_long_outlined,
                            color: AppColors.darkGreen,
                          ),
                        ),
                        title: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${item['category'] ?? 'Other'} · ${date.day}/${date.month}/${date.year}${isGrocery ? ' · Grocery item' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '₱${value.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (!isGrocery)
                              PopupMenuButton<String>(
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    _editExpense(expense: doc);
                                  }
                                  if (action == 'delete') {
                                    _deleteExpense(doc);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Color _statusColor(double percent) {
    if (percent >= 100) return const Color(0xFFCC7F7A);
    if (percent >= 90) return const Color(0xFFD99A59);
    if (percent >= 70) return const Color(0xFFD5B75C);
    return AppColors.primaryGreen;
  }

  String _budgetStatus(double percent) {
    if (percent >= 100) return 'Budget reached';
    if (percent >= 90) return 'Near budget limit';
    if (percent >= 70) return 'Approaching budget';
    return 'On track';
  }

  String _monthName(int month) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month - 1];

  DateTime _expenseDate(Map<String, dynamic> expense) {
    final value = expense['purchaseDate'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _weeklyRangeLabel(int index) {
    final first = index * 7 + 1;
    final last = math.min(
      first + 6,
      DateTime(_month.year, _month.month + 1, 0).day,
    );
    return '$first–$last';
  }
}

class _CategoryDonutCard extends StatelessWidget {
  const _CategoryDonutCard({required this.categories, required this.total});

  final List<MapEntry<String, double>> categories;
  final double total;
  static const _colors = [
    Color(0xFFA8E6A1),
    Color(0xFFFFD66B),
    Color(0xFFA7D8FF),
    Color(0xFFFF8F85),
    Color(0xFFC8B6E2),
    Color(0xFF75B7A2),
  ];

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spending by category',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (categories.isEmpty || total <= 0)
            const Text(
              'Category spending will appear as you add expenses.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CustomPaint(
                    painter: _DonutPainter(
                      values: categories.map((e) => e.value).toList(),
                      colors: _colors,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          '₱${total.toStringAsFixed(0)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < categories.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _colors[i % _colors.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  categories[i].key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${(categories[i].value / total * 100).round()}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values, required this.colors});
  final List<double> values;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(
      0,
      (runningTotal, value) => runningTotal + value,
    );
    if (total <= 0) return;
    var start = -math.pi / 2;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: math.min(size.width, size.height) / 2 - 12,
    );
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = colors[i % colors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.values != values || old.colors != colors;
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
    ],
  );
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.emptyMessage,
    required this.children,
  });

  final String title;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          if (children.isEmpty)
            Text(
              emptyMessage,
              style: const TextStyle(color: AppColors.textSecondary),
            )
          else
            ...children,
        ],
      ),
    ),
  );
}

class _PastelBar extends StatelessWidget {
  const _PastelBar({
    required this.label,
    required this.value,
    required this.maximum,
    required this.amountLabel,
  });

  final String label;
  final double value;
  final double maximum;
  final String amountLabel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              amountLabel,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: maximum == 0 ? 0 : value / maximum,
            minHeight: 8,
            color: const Color(0xFFA9C9A3),
            backgroundColor: const Color(0xFFF0F2EC),
          ),
        ),
      ],
    ),
  );
}
