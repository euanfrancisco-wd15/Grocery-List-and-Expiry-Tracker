import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/grocery.dart';
import '../services/auth_service.dart';
import '../services/grocery_service.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart';
import 'grocery_detail_screen.dart';
import 'grocery_form_screen.dart';
import 'inventory_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.authService, required this.user});

  final AuthService authService;
  final User user;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _groceryService = GroceryService();
  int _selectedIndex = 0;

  void _openAddGrocery() {
    setState(() {
      _selectedIndex = 2;
    });
  }

  void _openInventory() {
    setState(() {
      _selectedIndex = 1;
    });
  }

  void _openGroceryDetails(Grocery grocery) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroceryDetailScreen(
          user: widget.user,
          grocery: grocery,
          groceryService: _groceryService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        user: widget.user,
        groceryService: _groceryService,
        onAddGrocery: _openAddGrocery,
        onOpenGrocery: _openGroceryDetails,
      ),
      InventoryScreen(
        user: widget.user,
        groceryService: _groceryService,
        onAddGrocery: _openAddGrocery,
        onOpenGrocery: _openGroceryDetails,
      ),
      GroceryFormScreen(
        user: widget.user,
        groceryService: _groceryService,
        onSaved: _openInventory,
      ),
      _ProfilePreviewScreen(
        email: widget.user.email ?? 'No email available',
        onLogout: widget.authService.signOut,
      ),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        indicatorColor: AppColors.lightGreenBackground,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline_rounded),
            selectedIcon: Icon(Icons.add_circle_rounded),
            label: 'Add',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ProfilePreviewScreen extends StatelessWidget {
  const _ProfilePreviewScreen({required this.email, required this.onLogout});

  final String email;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Profile',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.account_circle_rounded,
                    color: AppColors.primaryGreen,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Logout'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
