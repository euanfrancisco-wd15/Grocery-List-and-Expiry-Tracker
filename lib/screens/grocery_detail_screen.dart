import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/grocery.dart';
import '../services/grocery_service.dart';
import '../theme/app_colors.dart';
import '../widgets/expiry_badge.dart';
import 'grocery_form_screen.dart';

class GroceryDetailScreen extends StatefulWidget {
  const GroceryDetailScreen({
    super.key,
    required this.user,
    required this.grocery,
    required this.groceryService,
  });

  final User user;
  final Grocery grocery;
  final GroceryService groceryService;

  @override
  State<GroceryDetailScreen> createState() => _GroceryDetailScreenState();
}

class _GroceryDetailScreenState extends State<GroceryDetailScreen> {
  late Grocery _grocery = widget.grocery;
  bool _isDeleting = false;

  Future<void> _editGrocery() async {
    final updated = await Navigator.of(context).push<Grocery>(
      MaterialPageRoute(
        builder: (_) => GroceryFormScreen(
          user: widget.user,
          groceryService: widget.groceryService,
          grocery: _grocery,
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _grocery = updated;
      });
    }
  }

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove grocery?'),
        content: const Text(
          'Are you sure you want to remove this grocery item?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await widget.groceryService.deleteGrocery(
        userId: widget.user.uid,
        groceryId: _grocery.id,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grocery deleted successfully.')),
      );
      Navigator.of(context).pop();
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _isDeleting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not delete this grocery. Please check your connection and try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grocery Details')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _grocery.name,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        ExpiryBadge(status: _grocery.expiryStatus),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage(_grocery),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _DetailRow(label: 'Category', value: _grocery.category),
                    _DetailRow(
                      label: 'Quantity',
                      value:
                          '${_formatQuantity(_grocery.quantity)} ${_grocery.unit}',
                    ),
                    _DetailRow(
                      label: 'Purchase Date',
                      value: _formatDate(_grocery.purchaseDate),
                    ),
                    _DetailRow(
                      label: 'Expiration Date',
                      value: _formatDate(_grocery.expirationDate),
                    ),
                    _DetailRow(
                      label: 'Storage Location',
                      value: _grocery.storageLocation.isEmpty
                          ? 'Not specified'
                          : _grocery.storageLocation,
                    ),
                    _DetailRow(
                      label: 'Notes',
                      value: _grocery.notes.isEmpty
                          ? 'No notes'
                          : _grocery.notes,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _isDeleting ? null : _editGrocery,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Edit'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isDeleting ? null : _confirmDelete,
              icon: _isDeleting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB91C1C),
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusMessage(Grocery grocery) {
    return switch (grocery.expiryStatus) {
      ExpiryStatus.safe => '${grocery.daysRemaining} days remaining',
      ExpiryStatus.expiringSoon => '${grocery.daysRemaining} days remaining',
      ExpiryStatus.expiresToday => 'Expires today',
      ExpiryStatus.expired => 'Expired ${grocery.daysRemaining.abs()} days ago',
    };
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
