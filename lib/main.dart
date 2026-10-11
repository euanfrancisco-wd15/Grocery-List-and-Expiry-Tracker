import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'firebase_options.dart';
import 'models/grocery.dart';
import 'screens/grocery_detail_screen.dart';
import 'screens/reports_screen.dart';
import 'services/device_notification_service.dart';
import 'services/grocery_service.dart';

String? _pendingNotificationPayload;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  timezone_data.initializeTimeZones();
  try {
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
  } on Object {
    // Keep the app usable if a platform does not expose timezone metadata.
  }
  Object? firebaseError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on Object catch (error) {
    firebaseError = error;
  }

  if (!kIsWeb && firebaseError == null) {
    await DeviceNotificationService.instance.initialize(
      onNotificationTap: (response) {
        final payload = response.payload;
        if (payload == null || !payload.contains('|')) return;
        final parts = payload.split('|');
        unawaited(_markNotificationRead(parts.first, parts.last));
        if (appNavigatorKey.currentState == null) {
          _pendingNotificationPayload = payload;
        } else {
          unawaited(_openNotificationPayload(payload));
        }
      },
    );
    if (kDebugMode &&
        const bool.fromEnvironment('GROPANDA_TEST_NOTIFICATION')) {
      await DeviceNotificationService.instance.sendTestNotification();
    }
  }

  runApp(GroceryTrackerApp(firebaseError: firebaseError));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final payload = _pendingNotificationPayload;
    _pendingNotificationPayload = null;
    if (payload != null) unawaited(_openNotificationPayload(payload));
  });
}

Future<void> _markNotificationRead(String uid, String notificationId) async {
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true, 'reminderSent': true});
  } on Object {
    // The in-app unread state can still be cleared from the Profile page.
  }
}

Future<void> _openNotificationPayload(String payload) async {
  final parts = payload.split('|');
  if (parts.length < 2) return;
  final uid = parts[0];
  final notificationId = parts[1];
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.uid != uid) return;
  try {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId);
    final notification = (await ref.get()).data();
    if (notification == null) return;
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      _pendingNotificationPayload = payload;
      return;
    }
    if (notification['type'] == 'budget') {
      final fields = (notification['month'] as String? ?? '').split('-');
      final year = fields.isNotEmpty ? int.tryParse(fields[0]) : null;
      final month = fields.length > 1 ? int.tryParse(fields[1]) : null;
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Budget Report')),
            body: ReportsScreen(
              userId: uid,
              initialMonth: year != null && month != null
                  ? DateTime(year, month)
                  : null,
            ),
          ),
        ),
      );
      return;
    }
    final itemId = notification['itemId'] as String?;
    if (itemId == null) return;
    final groceryDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('groceries')
        .doc(itemId)
        .get();
    if (!groceryDoc.exists) return;
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => GroceryDetailScreen(
          user: user,
          grocery: Grocery.fromFirestore(groceryDoc),
          groceryService: GroceryService(),
        ),
      ),
    );
  } on Object {
    // The notification remains available in the in-app notification center.
  }
}
