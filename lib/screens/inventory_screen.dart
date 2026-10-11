import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/grocery.dart';
import '../services/grocery_service.dart';
import '../theme/app_colors.dart';
import '../widgets/grocery_card.dart';
import '../widgets/section_header.dart';

enum InventoryStatusFilter { all, expiringSoon, expired }

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    super.key,
    required this.user,
    required this.groceryService,
    required this.onAddGrocery,
    required this.onOpenGrocery,
    this.initialStatus = InventoryStatusFilter.all,
  });

  final User user;
  final GroceryService groceryService;
  final VoidCallback onAddGrocery;
  final ValueChanged<Grocery> onOpenGrocery;
  final InventoryStatusFilter initialStatus;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const _categoryFilters = ['All', 'Produce', 'Dairy', 'Meat', 'Pantry'];

  final _searchController = TextEditingController();
  late InventoryStatusFilter _statusFilter = widget.initialStatus;
  String _selectedCategory = _categoryFilters.first;
  String _searchQuery = '';
  int _expiryWindow = 7;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<Grocery>>(
        stream: widget.groceryService.watchGroceries(widget.user.uid),
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final groceries = snapshot.data ?? [];
          final visibleGroceries = _applyFilters(groceries);

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            children: [
              SectionHeader(
                title: _screenTitle,
                subtitle: 'Find and manage the food you have at home.',
                icon: Icons.inventory_2_rounded,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search groceries',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              _StatusFilterChips(
                selected: _statusFilter,
                onChanged: (filter) {
                  setState(() {
                    _statusFilter = filter;
                  });
                },
              ),
              if (_statusFilter == InventoryStatusFilter.expiringSoon) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final days in [7, 3, 1])
                      ChoiceChip(
                        label: Text(days == 1 ? 'Tomorrow' : '$days Days'),
                        selected: _expiryWindow == days,
                        onSelected: (_) => setState(() => _expiryWindow = days),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              const SizedBox(height: 5),
              const Text(
                'Browse by category',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 9),
              _CategoryFilterChips(
                selected: _selectedCategory,
                categories: _categoryFilters,
                onChanged: (category) =>
                    setState(() => _selectedCategory = category),
              ),
              const SizedBox(height: 22),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  ),
                )
              else if (snapshot.hasError)
                _InventoryErrorState(
                  message: widget.groceryService.describeError(
                    snapshot.error!,
                    action: 'load your inventory',
                  ),
                )
              else if (groceries.isEmpty)
                _InventoryEmptyState(onAddGrocery: widget.onAddGrocery)
              else if (visibleGroceries.isEmpty)
                const _NoFilteredResultsState()
              else
                ...visibleGroceries.map(
                  (grocery) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GroceryCard(
                      grocery: grocery,
                      onTap: () => widget.onOpenGrocery(grocery),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String get _screenTitle => switch (widget.initialStatus) {
    InventoryStatusFilter.all => 'My Inventory',
    InventoryStatusFilter.expiringSoon => 'Expiring Soon',
    InventoryStatusFilter.expired => 'Expired Items',
  };

  List<Grocery> _applyFilters(List<Grocery> groceries) {
    return groceries.where((grocery) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          grocery.name.toLowerCase().contains(_searchQuery);

      final matchesStatus = switch (_statusFilter) {
        InventoryStatusFilter.all => true,
        InventoryStatusFilter.expiringSoon =>
          grocery.daysRemaining >= 0 &&
              (_expiryWindow == 1
                  ? grocery.daysRemaining == 1
                  : grocery.daysRemaining <= _expiryWindow),
        InventoryStatusFilter.expired => grocery.isExpired,
      };

      final category = grocery.category.toLowerCase();
      final matchesCategory = switch (_selectedCategory) {
        'All' => true,
        'Produce' => {'produce', 'fruits', 'vegetables'}.contains(category),
        'Dairy' => category == 'dairy',
        'Meat' => {'meat', 'seafood'}.contains(category),
        'Pantry' => !{
          'produce',
          'fruits',
          'vegetables',
          'dairy',
          'meat',
          'seafood',
        }.contains(category),
        _ => true,
      };

      return matchesSearch && matchesStatus && matchesCategory;
    }).toList();
  }
}

class _CategoryFilterChips extends StatelessWidget {
  const _CategoryFilterChips({
    required this.selected,
    required this.categories,
    required this.onChanged,
  });

  final String selected;
  final List<String> categories;
  final ValueChanged<String> onChanged;

  static const _icons = {
    'All': Icons.grid_view_rounded,
    'Produce': Icons.eco_rounded,
    'Dairy': Icons.water_drop_rounded,
    'Meat': Icons.set_meal_rounded,
    'Pantry': Icons.kitchen_rounded,
  };

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final category in categories) ...[
          ChoiceChip(
            avatar: Icon(
              _icons[category],
              size: 17,
              color: selected == category
                  ? AppColors.darkGreen
                  : AppColors.textSecondary,
            ),
            label: Text(category),
            selected: selected == category,
            onSelected: (_) => onChanged(category),
            selectedColor: AppColors.primaryGreen,
            backgroundColor: Colors.white,
            showCheckmark: false,
            labelStyle: TextStyle(
              color: selected == category
                  ? AppColors.darkGreen
                  : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            side: BorderSide(
              color: selected == category
                  ? AppColors.primaryGreen
                  : AppColors.borderGreen,
            ),
          ),
          if (category != categories.last) const SizedBox(width: 8),
        ],
      ],
    ),
  );
}

class _StatusFilterChips extends StatelessWidget {
  const _StatusFilterChips({required this.selected, required this.onChanged});

  final InventoryStatusFilter selected;
  final ValueChanged<InventoryStatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'Any Status',
            isSelected: selected == InventoryStatusFilter.all,
            onTap: () => onChanged(InventoryStatusFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Expiring Soon',
            isSelected: selected == InventoryStatusFilter.expiringSoon,
            onTap: () => onChanged(InventoryStatusFilter.expiringSoon),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Expired',
            isSelected: selected == InventoryStatusFilter.expired,
            onTap: () => onChanged(InventoryStatusFilter.expired),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.lightGreenBackground,
      checkmarkColor: AppColors.darkGreen,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.darkGreen : AppColors.textSecondary,
        fontWeight: FontWeight.w800,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: isSelected ? AppColors.primaryGreen : AppColors.borderGreen,
        ),
      ),
    );
  }
}

class _InventoryEmptyState extends StatelessWidget {
  const _InventoryEmptyState({required this.onAddGrocery});

  final VoidCallback onAddGrocery;

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
                  semanticLabel: 'GroPanda mascot ready to help with groceries',
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('🍎   🥕   🥦', style: TextStyle(fontSize: 22)),
            const SizedBox(height: 16),
            Text(
              'Your inventory is empty.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add your first grocery item.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAddGrocery,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Grocery'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoFilteredResultsState extends StatelessWidget {
  const _NoFilteredResultsState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Icon(Icons.search_off_rounded, color: AppColors.darkGreen),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No groceries match your current search and filters.',
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

class _InventoryErrorState extends StatelessWidget {
  const _InventoryErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
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
