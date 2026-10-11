import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';

class BackupService {
  BackupService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String _verifyOwner(String requestedUid) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
      );
    }
    if (uid != requestedUid) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    return uid;
  }

  Future<bool> exportToFile(String userId) async {
    final uid = _verifyOwner(userId);
    final profileRef = _firestore.collection('users').doc(uid);
    final profileSnapshot = await profileRef.get();
    final profile = profileSnapshot.data() ?? <String, dynamic>{};
    final appProfile = <String, dynamic>{
      for (final key in [
        'username',
        'usernameLower',
        'displayName',
        'photoURL',
        'profileCompleted',
        'monthlyBudget',
        'monthlyBudgets',
        'notificationEnabled',
        'notificationTime',
        'expiryReminder7Days',
        'expiryReminder3Days',
        'expiryReminder1Day',
        'expiryReminderOnExpiry',
        'budgetAlert70',
        'budgetAlert90',
        'budgetAlert100',
        'budgetAlertOver100',
      ])
        if (profile.containsKey(key)) key: profile[key],
    };
    final collections = <String, dynamic>{};
    for (final name in ['groceries', 'expenses', 'notifications']) {
      final snapshot = await profileRef.collection(name).get();
      collections[name] = [
        for (final doc in snapshot.docs)
          {'id': doc.id, 'data': _encode(doc.data())},
      ];
    }
    final backup = <String, dynamic>{
      'format': 'gropanda-backup',
      'version': 1,
      'userId': uid,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'profile': _encode(appProfile),
      'collections': collections,
    };
    final date = DateTime.now();
    final name =
        'gropanda-backup-${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}.json';
    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(backup)),
    );
    final result = await FilePicker.saveFile(
      fileName: name,
      bytes: bytes,
      mimeType: 'application/json',
      dialogTitle: 'Save GroPanda backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    return result != null;
  }

  Future<int> restoreFromFile(String userId) async {
    final uid = _verifyOwner(userId);
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      dialogTitle: 'Choose a GroPanda backup',
    );
    if (picked.isEmpty) return 0;
    final bytes = await picked.single.readAsBytes();
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
      throw const FormatException(
        'The backup file is empty or larger than 20 MB.',
      );
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'gropanda-backup' ||
        decoded['version'] != 1) {
      throw const FormatException('This is not a supported GroPanda backup.');
    }
    if (decoded['userId'] != uid) {
      throw const FormatException(
        'This backup belongs to a different GroPanda account. Sign in to its original account to restore it.',
      );
    }
    final collections = decoded['collections'];
    final profile = decoded['profile'];
    if (collections is! Map<String, dynamic> ||
        profile is! Map<String, dynamic>) {
      throw const FormatException('The backup file is missing account data.');
    }

    final profileRef = _firestore.collection('users').doc(uid);
    await profileRef.set(
      _decode(profile) as Map<String, dynamic>,
      SetOptions(merge: true),
    );
    var restored = 0;
    for (final name in ['groceries', 'expenses', 'notifications']) {
      final entries = collections[name];
      if (entries == null) continue;
      if (entries is! List) {
        throw FormatException('The $name backup data is invalid.');
      }
      for (var offset = 0; offset < entries.length; offset += 400) {
        final batch = _firestore.batch();
        final slice = entries.skip(offset).take(400);
        for (final entry in slice) {
          if (entry is! Map<String, dynamic> ||
              entry['id'] is! String ||
              entry['data'] is! Map<String, dynamic>) {
            throw FormatException('An entry in the $name backup is invalid.');
          }
          final reference = profileRef
              .collection(name)
              .doc(entry['id'] as String);
          batch.set(
            reference,
            _decode(entry['data'] as Map<String, dynamic>)
                as Map<String, dynamic>,
            SetOptions(merge: true),
          );
          restored++;
        }
        await batch.commit();
      }
    }
    return restored;
  }

  dynamic _encode(dynamic value) {
    if (value is Timestamp) {
      return {'__gropandaTimestamp': value.toDate().toUtc().toIso8601String()};
    }
    if (value is DateTime) {
      return {'__gropandaTimestamp': value.toUtc().toIso8601String()};
    }
    if (value is Map) {
      return value.map(
        (key, value) => MapEntry(key.toString(), _encode(value)),
      );
    }
    if (value is Iterable) return value.map(_encode).toList();
    return value;
  }

  dynamic _decode(dynamic value) {
    if (value is Map<String, dynamic>) {
      final timestamp = value['__gropandaTimestamp'];
      if (value.length == 1 && timestamp is String) {
        return Timestamp.fromDate(DateTime.parse(timestamp));
      }
      return value.map((key, value) => MapEntry(key, _decode(value)));
    }
    if (value is List) return value.map(_decode).toList();
    return value;
  }
}
