class BudgetAlertRules {
  const BudgetAlertRules._();

  static const thresholds = [70, 90, 100, 101];

  static List<int> reached({
    required double spend,
    required double budget,
    required Map<String, dynamic> preferences,
    Set<int> alreadyNotified = const {},
  }) {
    if (budget <= 0 || spend <= 0) return const [];
    return thresholds.where((threshold) {
      if (alreadyNotified.contains(threshold)) return false;
      final key = switch (threshold) {
        70 => 'budgetAlert70',
        90 => 'budgetAlert90',
        100 => 'budgetAlert100',
        _ => 'budgetAlertOver100',
      };
      if (preferences[key] == false) return false;
      return threshold == 101
          ? spend > budget
          : spend >= budget * threshold / 100;
    }).toList();
  }
}
