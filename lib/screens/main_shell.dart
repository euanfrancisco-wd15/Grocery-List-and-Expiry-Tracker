import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/grocery.dart';
import '../services/auth_service.dart';
import '../services/grocery_service.dart';
import '../services/device_notification_service.dart';
import '../services/backup_service.dart';
import '../theme/app_colors.dart';
import '../widgets/section_header.dart';
import 'dashboard_screen.dart';
import 'grocery_detail_screen.dart';
import 'grocery_form_screen.dart';
import 'inventory_screen.dart';
import 'reports_screen.dart';
import 'notifications_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.authService, required this.user});

  final AuthService authService;
  final User user;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _groceryService = GroceryService();
  final _deviceNotificationService = DeviceNotificationService.instance;
  int _selectedIndex = 0;
  DateTime? _reportsInitialMonth;

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

  void _openExpiryFilter(InventoryStatusFilter filter) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(
              filter == InventoryStatusFilter.expired
                  ? 'Expired Items'
                  : 'Expiring Soon',
            ),
          ),
          body: InventoryScreen(
            user: widget.user,
            groceryService: _groceryService,
            onAddGrocery: _openAddGrocery,
            onOpenGrocery: _openGroceryDetails,
            initialStatus: filter,
          ),
        ),
      ),
    );
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsScreen(
          userId: widget.user.uid,
          onOpenBudget: (month) {
            Navigator.of(context).pop();
            setState(() {
              _selectedIndex = 3;
              _reportsInitialMonth = month;
            });
          },
          onOpenExpiry: (itemId) async {
            Navigator.of(context).pop();
            final groceries = await _groceryService.getGroceries(
              widget.user.uid,
            );
            Grocery? item;
            for (final grocery in groceries) {
              if (grocery.id == itemId) {
                item = grocery;
                break;
              }
            }
            if (item != null && mounted) _openGroceryDetails(item);
          },
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
        onOpenReports: () => setState(() => _selectedIndex = 3),
        onOpenInventory: _openInventory,
        onOpenSettings: () => setState(() => _selectedIndex = 4),
        onOpenNotifications: _openNotifications,
        onOpenExpiring: () =>
            _openExpiryFilter(InventoryStatusFilter.expiringSoon),
        onOpenExpired: () => _openExpiryFilter(InventoryStatusFilter.expired),
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
        onCancel: _openInventory,
      ),
      ReportsScreen(
        userId: widget.user.uid,
        initialMonth: _reportsInitialMonth,
      ),
      _ProfilePreviewScreen(
        user: widget.user,
        authService: widget.authService,
        groceryService: _groceryService,
        onLogout: _signOut,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
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
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    await _deviceNotificationService.cancelAll();
    await widget.authService.signOut();
  }
}

class _ProfilePreviewScreen extends StatelessWidget {
  const _ProfilePreviewScreen({
    required this.user,
    required this.authService,
    required this.groceryService,
    required this.onLogout,
  });

  final User user;
  final AuthService authService;
  final GroceryService groceryService;
  final VoidCallback onLogout;
  static final _notificationService = DeviceNotificationService.instance;
  static final _backupService = BackupService();

  Future<void> _changePassword(BuildContext context) async {
    if (!user.providerData.any(
      (provider) => provider.providerId == 'password',
    )) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Password not available'),
          content: const Text(
            'This account uses Google sign-in. Manage its password through your Google account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isSaving = false;
    String? errorMessage;

    try {
      final changed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Change password'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPasswordController,
                    obscureText: true,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your current password.'
                        : null,
                  ),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                    ),
                    validator: (value) => value == null || value.length < 6
                        ? 'Use at least 6 characters.'
                        : null,
                  ),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                    ),
                    validator: (value) => value != newPasswordController.text
                        ? 'Passwords do not match.'
                        : null,
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          isSaving = true;
                          errorMessage = null;
                        });
                        try {
                          await authService.changePassword(
                            currentPassword: currentPasswordController.text,
                            newPassword: newPasswordController.text,
                          );
                          if (context.mounted) {
                            Navigator.of(context).pop(true);
                          }
                        } on FirebaseAuthException catch (error) {
                          if (context.mounted) {
                            setDialogState(() {
                              isSaving = false;
                              errorMessage = authService.friendlyAuthError(
                                error,
                              );
                            });
                          }
                        } on Object {
                          if (context.mounted) {
                            setDialogState(() {
                              isSaving = false;
                              errorMessage =
                                  'Could not change your password. Check your connection and try again.';
                            });
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Update password'),
              ),
            ],
          ),
        ),
      );
      if (changed == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully.')),
        );
      }
    } finally {
      currentPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    }
  }

  Future<void> _saveSettings(Map<String, dynamic> values) async {
    await authService.updateProfile(user.uid, values);
    final groceries = await groceryService.getGroceries(user.uid);
    await _notificationService.syncForUser(
      userId: user.uid,
      groceries: groceries,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<Map<String, dynamic>>(
        stream: authService.watchProfile(user.uid),
        builder: (context, snapshot) {
          final profile = snapshot.data ?? {};
          final enabled = profile['notificationEnabled'] as bool? ?? true;
          final time = profile['notificationTime'] as String? ?? '08:00';
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SectionHeader(
                title: 'Settings',
                subtitle: 'Your account and app preferences.',
                icon: Icons.settings_rounded,
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
                        '@${profile['username'] ?? 'shopper'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user.email ?? 'No email available',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 18),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Notification Settings',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      _SettingsSurface(
                        tint: AppColors.primaryGreen,
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          title: const Text('Notifications'),
                          value: enabled,
                          onChanged:
                              snapshot.connectionState ==
                                  ConnectionState.waiting
                              ? null
                              : (value) async {
                                  if (value) {
                                    final granted = await _notificationService
                                        .requestPermission();
                                    if (!granted) {
                                      if (context.mounted) {
                                        await showDialog<void>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text(
                                              'Allow phone notifications',
                                            ),
                                            content: const Text(
                                              'GroPanda needs notification permission to alert you about expiring groceries and budget thresholds. Enable notifications for GroPanda in your phone settings, then try again.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('OK'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                  }
                                  await _saveSettings({
                                    'notificationEnabled': value,
                                  });
                                  if (value) {
                                    await _notificationService
                                        .evaluateBudgetAfterExpense(
                                          userId: user.uid,
                                        );
                                  }
                                },
                        ),
                      ),
                      if (enabled)
                        FutureBuilder<bool>(
                          future: _notificationService
                              .areNotificationsEnabled(),
                          builder: (context, permissionSnapshot) {
                            if (permissionSnapshot.data != false) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Phone notifications are blocked. Enable GroPanda notifications in your Android system settings.',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      height: 1.35,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () async {
                                      final granted = await _notificationService
                                          .requestPermission();
                                      if (granted) {
                                        await _saveSettings({
                                          'notificationEnabled': true,
                                        });
                                        await _notificationService
                                            .evaluateBudgetAfterExpense(
                                              userId: user.uid,
                                            );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.notifications_active_outlined,
                                    ),
                                    label: const Text(
                                      'Request permission again',
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      _SettingsSurface(
                        tint: AppColors.accentBlue,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          leading: const Icon(
                            Icons.schedule_rounded,
                            color: AppColors.darkGreen,
                          ),
                          title: const Text('Preferred notification time'),
                          subtitle: Text(_formatNotificationTime(time)),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            final parts = time.split(':');
                            final value = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: int.tryParse(parts[0]) ?? 8,
                                minute: int.tryParse(parts[1]) ?? 0,
                              ),
                            );
                            if (value != null) {
                              await _saveSettings({
                                'notificationTime':
                                    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
                              });
                            }
                          },
                        ),
                      ),
                      ...[
                        ('7 days before', 'expiryReminder7Days'),
                        ('3 days before', 'expiryReminder3Days'),
                        ('1 day before', 'expiryReminder1Day'),
                        ('On expiry', 'expiryReminderOnExpiry'),
                        ('Budget alert at 70%', 'budgetAlert70'),
                        ('Budget alert at 90%', 'budgetAlert90'),
                        ('Budget alert at 100%', 'budgetAlert100'),
                        ('Budget alert above 100%', 'budgetAlertOver100'),
                      ].asMap().entries.map((indexedEntry) {
                        final entry = indexedEntry.value;
                        return _SettingsSurface(
                          tint: indexedEntry.key < 4
                              ? AppColors.accentYellow
                              : AppColors.accentBlue,
                          child: SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            title: Text(entry.$1),
                            value: profile[entry.$2] as bool? ?? true,
                            onChanged: (value) async {
                              await _saveSettings({entry.$2: value});
                              if (value && entry.$2.startsWith('budgetAlert')) {
                                await _notificationService
                                    .evaluateBudgetAfterExpense(
                                      userId: user.uid,
                                    );
                              }
                            },
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Text(
                        'Notifications',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      _NotificationsList(userId: user.uid),
                      const Divider(height: 28),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        tileColor: AppColors.accentBlue.withValues(alpha: .07),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: AppColors.accentBlue.withValues(alpha: .3),
                          ),
                        ),
                        leading: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.darkGreen,
                        ),
                        title: const Text('Account Security'),
                        subtitle: const Text(
                          'Change the password for your email account',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _changePassword(context),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            final email = user.email;
                            if (email == null || email.isEmpty) return;
                            try {
                              await authService.sendPasswordResetEmail(email);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Password reset email sent to $email.',
                                    ),
                                  ),
                                );
                              }
                            } on FirebaseAuthException catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      authService.friendlyAuthError(error),
                                    ),
                                  ),
                                );
                              }
                            } on Object {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Could not send the reset email. Check your connection and try again.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text(
                            'Forgot password? Send reset email',
                          ),
                        ),
                      ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        tileColor: AppColors.accentYellow.withValues(
                          alpha: .08,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: AppColors.accentYellow.withValues(
                              alpha: .32,
                            ),
                          ),
                        ),
                        leading: const Icon(
                          Icons.backup_outlined,
                          color: AppColors.darkGreen,
                        ),
                        title: const Text('Data Backup'),
                        subtitle: const Text(
                          'Save or restore a private JSON backup',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          builder: (sheetContext) => SafeArea(
                            child: Wrap(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.download_outlined),
                                  title: const Text('Export backup'),
                                  subtitle: const Text(
                                    'Save groceries, expenses, settings, and notifications',
                                  ),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    _runBackup(context, restore: false);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.restore_rounded),
                                  title: const Text('Restore backup'),
                                  subtitle: const Text(
                                    'Merge a backup for this account',
                                  ),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    _runBackup(context, restore: true);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        tileColor: AppColors.primaryGreen.withValues(
                          alpha: .07,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: AppColors.primaryGreen.withValues(
                              alpha: .34,
                            ),
                          ),
                        ),
                        leading: const Icon(
                          Icons.support_agent_rounded,
                          color: AppColors.darkGreen,
                        ),
                        title: const Text('Help & Support'),
                        subtitle: const Text('Account and reminder help'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Help & Support'),
                            content: const Text(
                              'Your grocery records and budgets are private to your signed-in account. Manage reminder time and alert types in Notification Settings. Use Account Security to change or reset your password.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        tileColor: AppColors.accentBlue.withValues(alpha: .07),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: AppColors.accentBlue.withValues(alpha: .3),
                          ),
                        ),
                        leading: const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.darkGreen,
                        ),
                        title: const Text('About GroPanda'),
                        subtitle: const Text('Version 1.0.0'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => showAboutDialog(
                          context: context,
                          applicationName: 'GroPanda',
                          applicationVersion: '1.0.0',
                          applicationIcon: Image.asset(
                            'assets/images/gropanda_logo.png',
                            width: 48,
                            height: 48,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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
          );
        },
      ),
    );
  }

  Future<void> _runBackup(BuildContext context, {required bool restore}) async {
    if (restore) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore GroPanda backup?'),
          content: const Text(
            'Records with matching IDs will be updated. Other records remain. Only a backup created by this signed-in account can be restored.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Choose Backup'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      if (restore) {
        final restored = await _backupService.restoreFromFile(user.uid);
        if (restored > 0 && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Restored $restored records.')),
          );
        }
      } else {
        final saved = await _backupService.exportToFile(user.uid);
        if (saved && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup exported. Keep the file somewhere safe.'),
            ),
          );
        }
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : 'Backup could not be completed. Check your connection and try again.',
            ),
          ),
        );
      }
    }
  }

  String _formatNotificationTime(String value) {
    final p = value.split(':');
    final h = int.tryParse(p[0]) ?? 8;
    final m = int.tryParse(p.length > 1 ? p[1] : '') ?? 0;
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
  }
}

class _SettingsSurface extends StatelessWidget {
  const _SettingsSurface({required this.tint, required this.child});

  final Color tint;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Card(
      color: Color.lerp(Colors.white, tint, .07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: tint.withValues(alpha: .3)),
      ),
      child: child,
    ),
  );
}

class _NotificationsList extends StatelessWidget {
  const _NotificationsList({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots(),
    builder: (context, snapshot) {
      final notifications = snapshot.data?.docs ?? [];
      if (notifications.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'No notifications yet.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        );
      }
      return Column(
        children: notifications.map((doc) {
          final data = doc.data();
          final isRead = data['read'] as bool? ?? false;
          final tint = data['type'] == 'budget'
              ? AppColors.accentBlue
              : AppColors.accentYellow;
          return _SettingsSurface(
            tint: tint,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              leading: Icon(
                isRead ? Icons.notifications_none : Icons.notifications_active,
                color: AppColors.darkGreen,
              ),
              title: Text(
                data['title'] as String? ??
                    data['message'] as String? ??
                    'Reminder',
                style: TextStyle(
                  fontWeight: isRead ? FontWeight.normal : FontWeight.w700,
                ),
              ),
              subtitle: Text(
                data['itemName'] as String? ??
                    data['month'] as String? ??
                    data['message'] as String? ??
                    '',
              ),
              onTap: isRead ? null : () => doc.reference.update({'read': true}),
            ),
          );
        }).toList(),
      );
    },
  );
}
