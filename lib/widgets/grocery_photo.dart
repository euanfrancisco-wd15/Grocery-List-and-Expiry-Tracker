import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/grocery_image_service.dart';
import '../theme/app_colors.dart';

class GroceryPhoto extends StatelessWidget {
  const GroceryPhoto({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.borderRadius = 16,
  });

  final String path;
  final double? width;
  final double? height;
  final double borderRadius;
  static final _imageService = GroceryImageService();

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: SizedBox(
      width: width,
      height: height,
      child: FutureBuilder<Uint8List?>(
        future: _imageService.readLocal(path),
        builder: (context, snapshot) => snapshot.data == null
            ? const ColoredBox(
                color: AppColors.lightGreenBackground,
                child: Center(
                  child: Icon(
                    Icons.shopping_basket_outlined,
                    color: AppColors.darkGreen,
                  ),
                ),
              )
            : Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: AppColors.lightGreenBackground,
                  child: Center(
                    child: Icon(
                      Icons.shopping_basket_outlined,
                      color: AppColors.darkGreen,
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
}
