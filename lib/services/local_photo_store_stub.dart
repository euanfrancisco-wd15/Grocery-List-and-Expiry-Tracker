import 'dart:typed_data';

Future<String> savePhoto(String groceryId, Uint8List bytes, String extension) =>
    Future.error(UnsupportedError('Local grocery photos are not supported.'));

Future<Uint8List?> readPhoto(String path) async => null;

Future<void> deletePhoto(String path) async {}
