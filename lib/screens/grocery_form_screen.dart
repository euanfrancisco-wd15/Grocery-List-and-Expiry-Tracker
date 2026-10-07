import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/grocery.dart';
import '../models/grocery_options.dart';
import '../services/grocery_service.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_text_field.dart';

class GroceryFormScreen extends StatefulWidget {
  const GroceryFormScreen({
    super.key,
    required this.user,
    required this.groceryService,
    this.grocery,
    this.onSaved,
  });

  final User user;
  final GroceryService groceryService;
  final Grocery? grocery;
  final VoidCallback? onSaved;

  @override
  State<GroceryFormScreen> createState() => _GroceryFormScreenState();
}

class _GroceryFormScreenState extends State<GroceryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _storageLocationController = TextEditingController();
  final _notesController = TextEditingController();

  late String _category;
  late String _unit;
  late DateTime _purchaseDate;
  DateTime? _expirationDate;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.grocery != null;

  @override
  void initState() {
    super.initState();
    final grocery = widget.grocery;
    _nameController.text = grocery?.name ?? '';
    _quantityController.text = grocery == null
        ? ''
        : _formatQuantity(grocery.quantity);
    _storageLocationController.text = grocery?.storageLocation ?? '';
    _notesController.text = grocery?.notes ?? '';
    _category = grocery?.category ?? GroceryOptions.categories.first;
    _unit = grocery?.unit ?? GroceryOptions.units.first;
    _purchaseDate = grocery?.purchaseDate ?? DateTime.now();
    _expirationDate = grocery?.expirationDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _storageLocationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_expirationDate == null) {
      setState(() {
        _errorMessage = 'Expiration date is required.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final now = DateTime.now();
    final grocery = Grocery(
      id: widget.grocery?.id ?? '',
      name: _nameController.text.trim(),
      category: _category,
      quantity: double.parse(_quantityController.text.trim()),
      unit: _unit,
      purchaseDate: _purchaseDate,
      expirationDate: _expirationDate!,
      storageLocation: _storageLocationController.text.trim(),
      notes: _notesController.text.trim(),
      createdAt: widget.grocery?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      if (_isEditing) {
        await widget.groceryService.updateGrocery(
          userId: widget.user.uid,
          grocery: grocery,
        );
      } else {
        await widget.groceryService.addGrocery(
          userId: widget.user.uid,
          grocery: grocery,
        );
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Grocery updated successfully.'
                : 'Grocery added successfully.',
          ),
        ),
      );
      widget.onSaved?.call();
      if (_isEditing) {
        Navigator.of(context).pop(grocery);
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = widget.groceryService.describeError(
          error,
          action: 'save this grocery',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _purchaseDate = picked;
      });
    }
  }

  Future<void> _pickExpirationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _expirationDate = picked;
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Edit Grocery' : 'Add Grocery';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              CustomTextField(
                controller: _nameController,
                label: 'Item Name',
                prefixIcon: Icons.shopping_basket_outlined,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Grocery name is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: GroceryOptions.categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _category = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _quantityController,
                      label: 'Quantity',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      prefixIcon: Icons.scale_outlined,
                      validator: (value) {
                        final quantity = double.tryParse((value ?? '').trim());
                        if (quantity == null || quantity <= 0) {
                          return 'Enter a valid quantity.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: GroceryOptions.units
                          .map(
                            (unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _unit = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _DateField(
                label: 'Purchase Date',
                value: _formatDate(_purchaseDate),
                icon: Icons.event_available_outlined,
                onTap: _pickPurchaseDate,
              ),
              const SizedBox(height: 14),
              _DateField(
                label: 'Expiration Date',
                value: _expirationDate == null
                    ? 'Select expiration date'
                    : _formatDate(_expirationDate!),
                icon: Icons.event_busy_outlined,
                onTap: _pickExpirationDate,
                isPlaceholder: _expirationDate == null,
              ),
              const SizedBox(height: 14),
              CustomTextField(
                controller: _storageLocationController,
                label: 'Storage Location',
                prefixIcon: Icons.kitchen_outlined,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                _FormErrorMessage(message: _errorMessage!),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isEditing ? 'Save Changes' : 'Save Grocery'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.isPlaceholder = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: Text(
          value,
          style: TextStyle(
            color: isPlaceholder
                ? AppColors.textSecondary
                : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _FormErrorMessage extends StatelessWidget {
  const _FormErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFB91C1C),
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
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
