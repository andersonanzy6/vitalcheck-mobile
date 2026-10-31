import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/utils/formatters.dart';
import 'chat_screen.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});
  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  late Future<dynamic> _future;
  @override
  void initState() {
    super.initState();
    _future = ref.read(apiProvider).get('/chat/conversations');
    ref.read(socketProvider)?.on('conversation-updated', (_) {
      if (mounted)
        setState(
          () => _future = ref.read(apiProvider).get('/chat/conversations'),
        );
    });
  }

  Future<void> _reload() async {
    setState(() => _future = ref.read(apiProvider).get('/chat/conversations'));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Messages', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            const Text(
              'Stay connected with your care team.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 18),
            FutureBuilder<dynamic>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                if (snapshot.hasError)
                  return ErrorPanel(
                    message: 'Messages could not be loaded.',
                    onRetry: _reload,
                  );
                final raw = snapshot.data;
                final List rows = raw is List
                    ? raw
                    : raw is Map && raw['conversations'] is List
                    ? raw['conversations'] as List
                    : const [];
                if (rows.isEmpty)
                  return const SurfaceCard(
                    child: Column(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: primaryBlue,
                          size: 34,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'No conversations yet',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Your doctor messages will appear here.',
                          style: TextStyle(color: muted),
                        ),
                      ],
                    ),
                  );
                return Column(
                  children: rows.map<Widget>((item) {
                    final row = item is Map
                        ? Map<String, dynamic>.from(item)
                        : <String, dynamic>{};
                    final other =
                        row['participant'] ??
                        row['user'] ??
                        row['doctor'] ??
                        row['patient'] ??
                        {};
                    final name = other is Map
                        ? str(other['name'], 'Care team')
                        : 'Care team';
                    final id = str(
                      other is Map
                          ? (other['_id'] ?? other['id'])
                          : row['userId'],
                    );
                    final last = row['lastMessage'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SurfaceCard(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ChatScreen(peerId: id, peerName: name),
                          ),
                        ),
                        child: Row(
                          children: [
                            avatar(name),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    str(
                                      last is Map ? last['message'] : last,
                                      'Tap to open conversation',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: muted),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: muted),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    ref.read(socketProvider)?.off('conversation-updated');
    super.dispose();
  }
}
