import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> savePhoto(
  String groceryId,
  Uint8List bytes,
  String extension,
) async {
  final documents = await getApplicationDocumentsDirectory();
  final directory = Directory('${documents.path}/grocery_photos');
  await directory.create(recursive: true);
  final file = File(
    '${directory.path}/${groceryId}_${DateTime.now().microsecondsSinceEpoch}.$extension',
  );
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<Uint8List?> readPhoto(String path) async {
  final documents = await getApplicationDocumentsDirectory();
  if (!path.startsWith('${documents.path}/grocery_photos/')) return null;
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

Future<void> deletePhoto(String path) async {
  final documents = await getApplicationDocumentsDirectory();
  if (!path.startsWith('${documents.path}/grocery_photos/')) return;
  final file = File(path);
  if (await file.exists()) await file.delete();
}
