import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/grocery.dart';
import 'budget_alert_rules.dart';
import 'monthly_budget_service.dart';

class DeviceNotificationService {
  static final instance = DeviceNotificationService._();

  DeviceNotificationService._()
    : _firestore = FirebaseFirestore.instance,
      _plugin = FlutterLocalNotificationsPlugin(),
      _auth = FirebaseAuth.instance;

  DeviceNotificationService({
    FirebaseFirestore? firestore,
    FlutterLocalNotificationsPlugin? plugin,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FlutterLocalNotificationsPlugin _plugin;
  final FirebaseAuth _auth;
  bool _syncing = false;
  String? _lastSyncKey;

  static const _channel = AndroidNotificationChannel(
    'groPanda_alerts',
    'GroPanda Alerts',
    description: 'Expiry and monthly budget alerts',
    importance: Importance.high,
  );

  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'groPanda_alerts',
      'GroPanda Alerts',
      channelDescription: 'Expiry and monthly budget alerts',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );

  Future<void> initialize({
    DidReceiveNotificationResponseCallback? onNotificationTap,
  }) async {
    if (kIsWeb) return;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: onNotificationTap,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        await requestPermission();
      case TargetPlatform.iOS:
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      case TargetPlatform.macOS:
        await _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      default:
        break;
    }
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true && response != null) {
      onNotificationTap?.call(response);
    }
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final enabled = await android?.areNotificationsEnabled();
    if (enabled == true) return true;
    return await android?.requestNotificationsPermission() ?? false;
  }

  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    final enabled = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.areNotificationsEnabled();
    return enabled ?? false;
  }

  Future<void> sendTestNotification() async {
    if (!kDebugMode) {
      throw UnsupportedError(
        'Test notifications are only available in debug builds.',
      );
    }
    if (!await areNotificationsEnabled()) {
      debugPrint(
        'Test notification skipped: enable GroPanda notifications in Android settings.',
      );
      return;
    }
    try {
      await _plugin.show(
        _stableId('gropanda-test-notification'),
        'GroPanda Test Notification',
        'Notifications are working!',
        _notificationDetails,
      );
      debugPrint('GroPanda test notification was posted to Android.');
    } on Object catch (error) {
      debugPrint('Test notification failed: $error');
    }
  }

  Future<void> cancelAll() => kIsWeb ? Future.value() : _plugin.cancelAll();

  Future<void> syncForUser({
    required String userId,
    required List<Grocery> groceries,
  }) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      await sync(
        userId: userId,
        groceries: groceries,
        profile: doc.data() ?? {},
      );
    } on Object {
      // The next dashboard refresh retries after a transient Firebase failure.
    }
  }

  Future<void> sync({
    required String userId,
    required List<Grocery> groceries,
    required Map<String, dynamic> profile,
  }) async {
    if (kIsWeb || _syncing) return;
    final syncKey =
        '$userId|${profile['notificationEnabled']}|${profile['notificationTime']}|${profile['monthlyBudget']}|${groceries.map((g) => '${g.id}:${g.expirationDate.millisecondsSinceEpoch}:${g.purchaseDate.millisecondsSinceEpoch}:${g.totalCost}').join(',')}|${profile.entries.where((e) => e.key.startsWith('expiryReminder') || e.key.startsWith('budgetAlert')).map((e) => '${e.key}:${e.value}').join(',')}';
    if (syncKey == _lastSyncKey) return;
    _syncing = true;
    try {
      await _plugin.cancelAll();
      if (profile['notificationEnabled'] == false) {
        _lastSyncKey = syncKey;
        return;
      }
      final parts = (profile['notificationTime'] as String? ?? '08:00').split(
        ':',
      );
      final hour = int.tryParse(parts[0]) ?? 8;
      final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
      final now = tz.TZDateTime.now(tz.local);
      final reminders = <(int, String, String)>[
        (7, 'expiryReminder7Days', 'expires in 7 days'),
        (3, 'expiryReminder3Days', 'expires in 3 days'),
        (1, 'expiryReminder1Day', 'expires tomorrow'),
        (0, 'expiryReminderOnExpiry', 'expires today'),
      ];

      for (final item in groceries) {
        final expiry = tz.TZDateTime(
          tz.local,
          item.expirationDate.year,
          item.expirationDate.month,
          item.expirationDate.day,
        );
        final days = DateTime(
          expiry.year,
          expiry.month,
          expiry.day,
        ).difference(DateTime(now.year, now.month, now.day)).inDays;
        for (final (offset, preference, suffix) in reminders) {
          if (profile[preference] == false || days < offset) continue;
          final reminderDate = expiry.subtract(Duration(days: offset));
          final when = _atUserTime(reminderDate, hour, minute, now);
          if (when == null) continue;
          final notificationId = _stableId(
            '$userId-${item.id}-expiry-$offset-${expiry.year}-${expiry.month}-${expiry.day}',
          );
          final recordId =
              '${item.id}_expiry_${offset}_${expiry.year}${expiry.month.toString().padLeft(2, '0')}${expiry.day.toString().padLeft(2, '0')}';
          await _scheduleAndRecord(
            userId: userId,
            recordId: recordId,
            notificationId: notificationId,
            title: 'Expiry reminder',
            body: 'Your ${item.name} $suffix.',
            payload: '$userId|$recordId',
            scheduled: when,
            fields: {
              'itemId': item.id,
              'itemName': item.name,
              'type': 'expiry',
              'expiryDate': Timestamp.fromDate(expiry),
            },
          );
        }
      }
      _lastSyncKey = syncKey;
    } finally {
      _syncing = false;
    }
  }

  Future<void> evaluateBudgetAfterExpense({
    required String userId,
    DateTime? month,
  }) async {
    try {
      await _evaluateBudgetAfterExpense(userId: userId, month: month);
    } on Object catch (error) {
      debugPrint('Budget notification could not be delivered: $error');
    }
  }

  Future<void> _evaluateBudgetAfterExpense({
    required String userId,
    DateTime? month,
  }) async {
    if (kIsWeb || _auth.currentUser?.uid != userId) return;
    final profileRef = _firestore.collection('users').doc(userId);
    final profile = (await profileRef.get()).data() ?? <String, dynamic>{};
    if (profile['notificationEnabled'] == false) return;

    final now = month ?? DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    final monthKey = MonthlyBudgetService.monthKey(now);
    final budget = MonthlyBudgetService.budgetFromProfile(profile, now);
    if (budget <= 0) return;

    final expenseSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .where(
          'purchaseDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
        )
        .where('purchaseDate', isLessThan: Timestamp.fromDate(nextMonth))
        .get();
    final monthlySpent = MonthlyBudgetService.sumExpenses(
      expenseSnapshot.docs.map((doc) => doc.data()),
    );
    final thresholds = BudgetAlertRules.reached(
      spend: monthlySpent,
      budget: budget,
      preferences: profile,
    );
    final monthName = _monthName(now.month);
    final percentUsed = monthlySpent / budget * 100;

    for (final threshold in thresholds) {
      final exceeded = threshold == 101;
      final recordId = 'budget_${monthKey}_$threshold';
      final title = exceeded ? 'Budget Exceeded' : 'Budget Alert';
      final body = switch (threshold) {
        70 => "You've used 70% of your $monthName budget.",
        90 => "You've used 90% of your $monthName budget.",
        100 => 'You have reached your $monthName budget limit.',
        _ =>
          'You have exceeded your $monthName budget by ₱${(monthlySpent - budget).toStringAsFixed(2)}.',
      };
      final recordRef = profileRef.collection('notifications').doc(recordId);
      final phoneNotificationPending = await _firestore.runTransaction<bool>((
        tx,
      ) async {
        final previous = await tx.get(recordRef);
        if (!previous.exists) {
          tx.set(recordRef, {
            'userId': userId,
            'type': 'budget',
            'title': title,
            'message': body,
            'month': monthKey,
            'threshold': threshold,
            'budgetAmount': budget,
            'amountSpent': monthlySpent,
            'percentage': percentUsed,
            'read': false,
            'phoneNotificationShown': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
          return true;
        }
        return previous.data()?['phoneNotificationShown'] != true;
      });

      if (!phoneNotificationPending || !await areNotificationsEnabled()) {
        continue;
      }
      try {
        await _plugin.show(
          _stableId('$userId-$recordId'),
          title,
          body,
          _notificationDetails,
          payload: '$userId|$recordId',
        );
        await recordRef.set({
          'phoneNotificationShown': true,
        }, SetOptions(merge: true));
      } on Object {
        // Keep the in-app history entry; a later expense or permission change retries locally.
      }
    }
  }

  Future<void> _scheduleAndRecord({
    required String userId,
    required String recordId,
    required int notificationId,
    required String title,
    required String body,
    required String payload,
    required tz.TZDateTime scheduled,
    required Map<String, Object> fields,
  }) async {
    final ref = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(recordId);
    final record = await ref.get();
    if (record.data()?['reminderSent'] == true &&
        record.data()?['scheduledAt'] != null) {
      return;
    }
    final priorSchedule = record.data()?['scheduledAt'];
    if (priorSchedule is Timestamp &&
        !priorSchedule.toDate().isAfter(DateTime.now())) {
      await ref.set({'reminderSent': true}, SetOptions(merge: true));
      return;
    }
    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      scheduled,
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
    await ref.set({
      ...fields,
      'userId': userId,
      'message': body,
      'createdAt': record.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
      'scheduledAt': Timestamp.fromDate(scheduled),
      'read': record.data()?['read'] ?? false,
      'reminderSent': false,
      'reminderScheduled': true,
    }, SetOptions(merge: true));
  }

  tz.TZDateTime? _atUserTime(
    tz.TZDateTime date,
    int hour,
    int minute,
    tz.TZDateTime now,
  ) {
    var scheduled = tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    return scheduled.isAfter(now) ? scheduled : null;
  }

  String _monthName(int month) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month - 1];

  int _stableId(String value) {
    var hash = 0;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }
}
