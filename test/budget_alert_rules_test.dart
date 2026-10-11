import 'package:grocery_tracker/services/budget_alert_rules.dart';
import 'package:grocery_tracker/services/monthly_budget_service.dart';
import 'package:test/test.dart';

void main() {
  group('MonthlyBudgetService month helpers', () {
    test('uses the configured budget for the selected month', () {
      expect(
        MonthlyBudgetService.budgetFromProfile(
          const {
            'monthlyBudget': 1000,
            'monthlyBudgets': {'2026-10': 5000, '2026-11': 6000},
          },
          DateTime(2026, 11),
          today: DateTime(2026, 10),
        ),
        6000,
      );
    });

    test('does not reuse one permanent budget for a different month', () {
      expect(
        MonthlyBudgetService.budgetFromProfile(
          const {'monthlyBudget': 5000},
          DateTime(2026, 11),
          today: DateTime(2026, 10),
        ),
        0,
      );
    });

    test('formats month keys with a leading zero', () {
      expect(MonthlyBudgetService.monthKey(DateTime(2026, 2)), '2026-02');
    });
  });

  group('BudgetAlertRules', () {
    const enabled = <String, dynamic>{};

    test('does not alert below 70 percent', () {
      expect(
        BudgetAlertRules.reached(spend: 69, budget: 100, preferences: enabled),
        isEmpty,
      );
    });

    test('fires each threshold as it is reached', () {
      expect(
        BudgetAlertRules.reached(spend: 70, budget: 100, preferences: enabled),
        [70],
      );
      expect(
        BudgetAlertRules.reached(spend: 90, budget: 100, preferences: enabled),
        [70, 90],
      );
      expect(
        BudgetAlertRules.reached(spend: 100, budget: 100, preferences: enabled),
        [70, 90, 100],
      );
      expect(
        BudgetAlertRules.reached(spend: 101, budget: 100, preferences: enabled),
        [70, 90, 100, 101],
      );
    });

    test('respects individual disabled alerts', () {
      expect(
        BudgetAlertRules.reached(
          spend: 110,
          budget: 100,
          preferences: const {
            'budgetAlert70': false,
            'budgetAlert90': true,
            'budgetAlert100': false,
            'budgetAlertOver100': true,
          },
        ),
        [90, 101],
      );
    });

    test('does not repeat thresholds already notified this month', () {
      expect(
        BudgetAlertRules.reached(
          spend: 105,
          budget: 100,
          preferences: enabled,
          alreadyNotified: {70, 90, 100},
        ),
        [101],
      );
    });

    test('does not evaluate a zero or negative budget', () {
      expect(
        BudgetAlertRules.reached(spend: 100, budget: 0, preferences: enabled),
        isEmpty,
      );
      expect(
        BudgetAlertRules.reached(spend: 100, budget: -1, preferences: enabled),
        isEmpty,
      );
    });
  });
}
