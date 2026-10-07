import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/grocery.dart';
import '../models/grocery_options.dart';
import '../services/grocery_service.dart';
import '../theme/app_colors.dart';
import '../widgets/grocery_card.dart';

enum InventoryStatusFilter { all, expiringSoon, expired }

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
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
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const _categories = ['All Categories', ...GroceryOptions.categories];

  final _searchController = TextEditingController();
  InventoryStatusFilter _statusFilter = InventoryStatusFilter.all;
  String _selectedCategory = _categories.first;
  String _searchQuery = '';

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
              Text(
                'My Inventory',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.category_outlined),
                  labelText: 'Category',
                ),
                items: _categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedCategory = value;
                  });
                },
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

  List<Grocery> _applyFilters(List<Grocery> groceries) {
    return groceries.where((grocery) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          grocery.name.toLowerCase().contains(_searchQuery);

      final matchesStatus = switch (_statusFilter) {
        InventoryStatusFilter.all => true,
        InventoryStatusFilter.expiringSoon => grocery.isExpiringSoon,
        InventoryStatusFilter.expired => grocery.isExpired,
      };

      final matchesCategory =
          _selectedCategory == _categories.first ||
          grocery.category == _selectedCategory;

      return matchesSearch && matchesStatus && matchesCategory;
    }).toList();
  }
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
            label: 'All',
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
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppColors.lightGreenBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_shopping_cart_rounded,
                color: AppColors.primaryGreen,
                size: 40,
              ),
            ),
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
