import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.userId,
    required this.onOpenExpiry,
    required this.onOpenBudget,
  });

  final String userId;
  final ValueChanged<String> onOpenExpiry;
  final ValueChanged<DateTime?> onOpenBudget;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _filter = 0;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('notifications');

  Future<void> _markAllRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final doc
        in docs.where((doc) => doc.data()['read'] != true).take(450)) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: SafeArea(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _notifications
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Notifications could not be loaded. Check your connection and try again.',
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data?.docs ?? [];
          final visible = all.where((doc) {
            final type = doc.data()['type'];
            return _filter == 0 ||
                (_filter == 1 ? type == 'budget' : type == 'expiry');
          }).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: all.any((doc) => doc.data()['read'] != true)
                      ? () => _markAllRead(all)
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.darkGreen,
                  ),
                  child: const Text('Mark all read'),
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('All')),
                  ButtonSegment(value: 1, label: Text('Budget')),
                  ButtonSegment(value: 2, label: Text('Expiry')),
                ],
                selected: {_filter},
                onSelectionChanged: (selected) =>
                    setState(() => _filter = selected.first),
              ),
              const SizedBox(height: 16),
              if (visible.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 42,
                          color: AppColors.primaryGreen,
                        ),
                        SizedBox(height: 10),
                        Text('You’re all caught up.'),
                      ],
                    ),
                  ),
                ),
              ...visible.map((doc) {
                final data = doc.data();
                final type = data['type'] as String? ?? 'expiry';
                final read = data['read'] == true;
                final timestamp = data['createdAt'];
                final date = timestamp is Timestamp ? timestamp.toDate() : null;
                final title =
                    data['title'] as String? ??
                    (type == 'budget' ? 'Budget update' : 'Expiry reminder');
                final message = data['message'] as String? ?? '';
                final noticeTint = type == 'budget'
                    ? AppColors.accentBlue
                    : AppColors.accentYellow;
                return Card(
                  color: read
                      ? Color.lerp(Colors.white, noticeTint, .06)!
                      : Color.lerp(
                          AppColors.secondaryBackground,
                          noticeTint,
                          .1,
                        )!,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: BorderSide(
                      color: noticeTint.withValues(alpha: read ? .28 : .48),
                      width: read ? 1 : 1.2,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: type == 'budget'
                          ? AppColors.accentBlue.withValues(alpha: .4)
                          : AppColors.accentYellow.withValues(alpha: .55),
                      child: Icon(
                        type == 'budget'
                            ? Icons.savings_outlined
                            : Icons.event_busy_outlined,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    title: Text(
                      title,
                      style: TextStyle(
                        fontWeight: read ? FontWeight.w600 : FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      [
                        message,
                        if (date != null) _formatDate(date),
                      ].where((s) => s.isNotEmpty).join('\n'),
                    ),
                    isThreeLine: message.contains('\n'),
                    onTap: () async {
                      if (!read) await doc.reference.update({'read': true});
                      if (!context.mounted) return;
                      if (type == 'budget') {
                        final month = data['month'] as String?;
                        final parts = month?.split('-') ?? const <String>[];
                        final year = parts.isEmpty
                            ? null
                            : int.tryParse(parts[0]);
                        final monthNumber = parts.length < 2
                            ? null
                            : int.tryParse(parts[1]);
                        widget.onOpenBudget(
                          year != null && monthNumber != null
                              ? DateTime(year, monthNumber)
                              : null,
                        );
                      } else {
                        final itemId = data['itemId'] as String?;
                        if (itemId != null) widget.onOpenExpiry(itemId);
                      }
                    },
                  ),
                );
              }),
            ],
          );
        },
      ),
    ),
  );

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
