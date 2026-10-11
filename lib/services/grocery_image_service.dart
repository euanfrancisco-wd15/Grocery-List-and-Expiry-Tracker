import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'local_photo_store_stub.dart'
    if (dart.library.io) 'local_photo_store_io.dart'
    if (dart.library.js_interop) 'local_photo_store_web.dart'
    as platform;

/// Stores grocery photos in app-private device storage. Photos are not synced.
class GroceryImageService {
  Future<String> saveLocal({
    required String groceryId,
    required XFile image,
  }) async {
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw ArgumentError('Choose an image smaller than 5 MB.');
    }
    final extension = image.name.split('.').last.toLowerCase();
    if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      throw ArgumentError('Choose a JPG, PNG, or WebP image.');
    }

    return platform.savePhoto(groceryId, Uint8List.fromList(bytes), extension);
  }

  Future<Uint8List?> readLocal(String path) => platform.readPhoto(path);

  Future<void> deleteLocal(String? path) async {
    if (path == null || path.isEmpty) return;
    await platform.deletePhoto(path);
  }
}
