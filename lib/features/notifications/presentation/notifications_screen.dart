import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/utils/formatters.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late Future<dynamic> _future;
  @override
  void initState() {
    super.initState();
    _future = ref.read(apiProvider).get('/notifications');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        TextButton(
          onPressed: () async {
            try {
              await ref
                  .read(apiProvider)
                  .dio
                  .patch('/notifications/mark-all-read');
            } catch (_) {}
            if (mounted)
              setState(
                () => _future = ref.read(apiProvider).get('/notifications'),
              );
          },
          child: const Text('Mark all read'),
        ),
      ],
    ),
    body: FutureBuilder<dynamic>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Padding(
            padding: const EdgeInsets.all(20),
            child: ErrorPanel(
              message: 'Notifications could not be loaded.',
              onRetry: () => setState(
                () => _future = ref.read(apiProvider).get('/notifications'),
              ),
            ),
          );
        final raw = snapshot.data;
        final rows = raw is List
            ? raw
            : raw is Map && raw['notifications'] is List
            ? raw['notifications'] as List
            : const [];
        if (rows.isEmpty)
          return const Center(child: Text('You are all caught up.'));
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final n = rows[i] is Map
                ? Map<String, dynamic>.from(rows[i])
                : <String, dynamic>{};
            return SurfaceCard(
              onTap: () async {
                try {
                  await ref
                      .read(apiProvider)
                      .dio
                      .patch('/notifications/${str(n['_id'] ?? n['id'])}/read');
                } catch (_) {}
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFEAF1FF),
                    child: Icon(
                      Icons.notifications_active_outlined,
                      color: primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          str(n['title'], 'VitalCheck update'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          str(n['message'] ?? n['body']),
                          style: const TextStyle(color: muted),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dateLabel(n['createdAt']),
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}
