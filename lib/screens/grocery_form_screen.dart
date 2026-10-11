import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/grocery.dart';
import '../models/grocery_options.dart';
import '../services/grocery_service.dart';
import '../services/device_notification_service.dart';
import '../services/grocery_image_service.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/section_header.dart';

class GroceryFormScreen extends StatefulWidget {
  const GroceryFormScreen({
    super.key,
    required this.user,
    required this.groceryService,
    this.grocery,
    this.onSaved,
    this.onCancel,
  });

  final User user;
  final GroceryService groceryService;
  final Grocery? grocery;
  final VoidCallback? onSaved;
  final VoidCallback? onCancel;

  @override
  State<GroceryFormScreen> createState() => _GroceryFormScreenState();
}

class _GroceryFormScreenState extends State<GroceryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _storageLocationController = TextEditingController();
  final _notesController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _imageService = GroceryImageService();

  late String _category;
  late String _unit;
  late DateTime _purchaseDate;
  DateTime? _expirationDate;
  bool _isSaving = false;
  String? _errorMessage;
  XFile? _pickedImage;
  bool _removeExistingImage = false;
  late Future<Uint8List?> _existingImageBytes;

  bool get _isEditing => widget.grocery != null;

  @override
  void initState() {
    super.initState();
    final grocery = widget.grocery;
    _existingImageBytes = _imageService.readLocal(grocery?.imagePath ?? '');
    _nameController.text = grocery?.name ?? '';
    _quantityController.text = grocery == null
        ? ''
        : _formatQuantity(grocery.quantity);
    _unitPriceController.text = grocery == null || grocery.unitPrice == 0
        ? ''
        : grocery.unitPrice.toStringAsFixed(2);
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
    _unitPriceController.dispose();
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
    if (DateTime(
      _expirationDate!.year,
      _expirationDate!.month,
      _expirationDate!.day,
    ).isBefore(
      DateTime(_purchaseDate.year, _purchaseDate.month, _purchaseDate.day),
    )) {
      setState(() {
        _errorMessage =
            'Expiration date cannot be earlier than the purchase date.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final now = DateTime.now();
    final groceryId =
        widget.grocery?.id ??
        widget.groceryService.createGroceryId(widget.user.uid);
    String? savedLocalImagePath;
    final previousImagePath = widget.grocery?.imagePath;
    var imagePath = _removeExistingImage ? null : previousImagePath;
    try {
      if (_pickedImage != null) {
        savedLocalImagePath = await _imageService.saveLocal(
          groceryId: groceryId,
          image: _pickedImage!,
        );
        imagePath = savedLocalImagePath;
      }
      final grocery = Grocery(
        id: groceryId,
        name: _nameController.text.trim(),
        category: _category,
        quantity: double.parse(_quantityController.text.trim()),
        unitPrice: double.tryParse(_unitPriceController.text.trim()) ?? 0,
        unit: _unit,
        purchaseDate: _purchaseDate,
        expirationDate: _expirationDate!,
        storageLocation: _storageLocationController.text.trim(),
        notes: _notesController.text.trim(),
        createdAt: widget.grocery?.createdAt ?? now,
        updatedAt: now,
        imagePath: imagePath,
      );

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
      if (previousImagePath != null && previousImagePath != imagePath) {
        try {
          await _imageService.deleteLocal(previousImagePath);
        } on Object {
          // A stale photo can be cleaned up later without failing the grocery save.
        }
      }
      await DeviceNotificationService.instance.evaluateBudgetAfterExpense(
        userId: widget.user.uid,
      );

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
      if (savedLocalImagePath != null) {
        try {
          await _imageService.deleteLocal(savedLocalImagePath);
        } on Object {
          // Preserve the original save error if local cleanup fails.
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _describeSaveError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _describeSaveError(Object error) {
    if (error is ArgumentError) {
      return error.message?.toString() ?? 'The selected image is not valid.';
    }
    return widget.groceryService.describeError(
      error,
      action: 'save this grocery',
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (image != null && mounted) {
        setState(() {
          _pickedImage = image;
          _removeExistingImage = false;
          _errorMessage = null;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Could not select that image. ${error.toString()}',
        );
      }
    }
  }

  Future<void> _showImageOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_pickedImage != null ||
                (widget.grocery?.imagePath != null && !_removeExistingImage))
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _pickedImage = null;
                    _removeExistingImage = true;
                  });
                },
              ),
          ],
        ),
      ),
    );
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
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            children: [
              SectionHeader(
                title: title,
                subtitle: _isEditing
                    ? 'Update the details and keep it fresh.'
                    : 'Add an item and keep your pantry up to date.',
                icon: _isEditing
                    ? Icons.edit_note_rounded
                    : Icons.add_shopping_cart_rounded,
              ),
              const SizedBox(height: 18),
              _photoField(),
              const SizedBox(height: 16),
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
                        if (quantity == null ||
                            !quantity.isFinite ||
                            quantity <= 0) {
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
              CustomTextField(
                controller: _unitPriceController,
                label: 'Price per unit (optional)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                prefixIcon: Icons.payments_outlined,
                validator: (value) {
                  final price = double.tryParse((value ?? '').trim());
                  if ((value ?? '').trim().isNotEmpty &&
                      (price == null || !price.isFinite || price < 0)) {
                    return 'Enter a valid price.';
                  }
                  return null;
                },
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
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isSaving
                    ? null
                    : (widget.onCancel ??
                          () => Navigator.of(context).maybePop()),
                child: const Text('Cancel'),
              ),
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

  Widget _photoField() {
    Widget preview;
    if (_pickedImage != null) {
      preview = FutureBuilder<Uint8List>(
        future: _pickedImage!.readAsBytes(),
        builder: (context, snapshot) => snapshot.hasData
            ? Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                width: double.infinity,
              )
            : const Center(child: CircularProgressIndicator()),
      );
    } else if (!_removeExistingImage && widget.grocery?.imagePath != null) {
      preview = FutureBuilder<Uint8List?>(
        future: _existingImageBytes,
        builder: (context, snapshot) => snapshot.data == null
            ? const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 36,
                  color: AppColors.textSecondary,
                ),
              )
            : Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 36,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
      );
    } else {
      preview = const ColoredBox(
        color: AppColors.lightGreenBackground,
        child: Center(
          child: Icon(
            Icons.add_a_photo_outlined,
            size: 34,
            color: AppColors.darkGreen,
          ),
        ),
      );
    }
    final hasPhoto =
        _pickedImage != null ||
        (!_removeExistingImage && widget.grocery?.imagePath != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Item Photo',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Add a clear photo to recognize this grocery later.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(width: 88, height: 88, child: preview),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasPhoto ? 'Photo selected' : 'No photo added',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: _isSaving ? null : _showImageOptions,
                        icon: Icon(
                          hasPhoto
                              ? Icons.edit_outlined
                              : Icons.add_a_photo_outlined,
                        ),
                        label: Text(
                          hasPhoto ? 'Change photo' : 'Choose photo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasPhoto)
                        TextButton.icon(
                          onPressed: _isSaving
                              ? null
                              : () => setState(() {
                                  _pickedImage = null;
                                  _removeExistingImage = true;
                                }),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('Remove'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
