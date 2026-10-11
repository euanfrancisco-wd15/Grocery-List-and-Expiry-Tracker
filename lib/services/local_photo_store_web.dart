import 'dart:convert';
import 'dart:typed_data';

import 'package:sembast_web/sembast_web.dart';

Database? _database;
final _photos = StoreRef<String, String>.main();

Future<Database> _openDatabase() async => _database ??= await databaseFactoryWeb
    .openDatabase('gropanda_local_photos');

Future<String> savePhoto(
  String groceryId,
  Uint8List bytes,
  String extension,
) async {
  final key =
      'local-photo:$groceryId-${DateTime.now().microsecondsSinceEpoch}.$extension';
  final database = await _openDatabase();
  await _photos.record(key).put(database, base64Encode(bytes));
  return key;
}

Future<Uint8List?> readPhoto(String path) async {
  if (!path.startsWith('local-photo:')) return null;
  final database = await _openDatabase();
  final encoded = await _photos.record(path).get(database);
  return encoded == null ? null : Uint8List.fromList(base64Decode(encoded));
}

Future<void> deletePhoto(String path) async {
  if (!path.startsWith('local-photo:')) return;
  final database = await _openDatabase();
  await _photos.record(path).delete(database);
}
