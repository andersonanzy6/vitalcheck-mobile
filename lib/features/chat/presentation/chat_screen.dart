import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../calls/presentation/call_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.peerId, required this.peerName});
  final String peerId, peerName;
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true, _typing = false, _online = false;
  Timer? _typingTimer;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
    final socket = ref.read(socketProvider);
    socket?.on('message-received', _onMessage);
    socket?.on('message-sent', _onMessage);
    socket?.on('user_online', _onOnline);
    socket?.on('user_offline', _onOffline);
    socket?.on('user-typing', _onTyping);
    socket?.on('user-stop-typing', _onStopTyping);
    socket?.on('message-delivered', _onDelivery);
    socket?.on('messages-read', _onDelivery);
  }

  Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : {};
  void _onMessage(dynamic event) {
    final m = _map(event);
    if (m.isEmpty) return;
    if (m['sender'] is Map) {
      final sender = _map(m['sender']);
      if (str(sender['_id'] ?? sender['id']) != widget.peerId &&
          str(m['receiverId']) != widget.peerId)
        return;
    }
    if (!_messages.any(
      (x) => str(x['_id'] ?? x['id']) == str(m['_id'] ?? m['id']),
    ))
      setState(() => _messages.add(m));
    _markRead();
  }

  void _onOnline(dynamic e) {
    if (str(_map(e)['userId']) == widget.peerId) setState(() => _online = true);
  }

  void _onOffline(dynamic e) {
    if (str(_map(e)['userId']) == widget.peerId)
      setState(() => _online = false);
  }

  void _onTyping(dynamic e) {
    if (str(_map(e)['userId']) == widget.peerId) setState(() => _typing = true);
  }

  void _onStopTyping(dynamic e) {
    if (str(_map(e)['userId']) == widget.peerId)
      setState(() => _typing = false);
  }

  void _onDelivery(dynamic e) {
    final payload = _map(e);
    final ids = payload['messageIds'];
    if (ids is List)
      setState(() {
        for (final m in _messages) {
          if (ids.contains(m['_id']))
            m['_delivery'] =
                payload['read'] == true || payload['event'] == 'messages-read'
                ? 'read'
                : 'delivered';
        }
      });
  }

  Future<void> _load() async {
    try {
      final data = await ref
          .read(apiProvider)
          .get('/chat/conversation/${widget.peerId}');
      final rows = data is List
          ? data
          : data is Map && data['messages'] is List
          ? data['messages'] as List
          : const [];
      if (mounted) setState(() => _messages = rows.map(_map).toList());
      await _markRead();
    } catch (e) {
      if (mounted)
        setState(() => _error = 'Could not load this conversation. $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead() async {
    try {
      await ref.read(apiProvider).dio.patch('/chat/read/${widget.peerId}');
    } catch (_) {}
  }

  void _typingChange(String value) {
    final socket = ref.read(socketProvider);
    socket?.emit('user-typing', {'receiverId': widget.peerId});
    _typingTimer?.cancel();
    _typingTimer = Timer(
      const Duration(seconds: 2),
      () => socket?.emit('user-stop-typing', {'receiverId': widget.peerId}),
    );
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    _text.clear();
    ref.read(socketProvider)?.emit('stop-typing', {
      'receiverId': widget.peerId,
    });
    final socket = ref.read(socketProvider);
    if (socket?.connected == true) {
      socket!.emit('send-message', {
        'receiverId': widget.peerId,
        'message': text,
        'appointmentId': null,
        'messageType': 'text',
      });
    } else {
      try {
        final sent = await ref.read(apiProvider).post('/chat/send', {
          'receiverId': widget.peerId,
          'message': text,
        });
        setState(() => _messages.add(_map(sent)));
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Message not sent: $e')));
      }
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _text.dispose();
    _scroll.dispose();
    final socket = ref.read(socketProvider);
    for (final e in [
      'message-received',
      'message-sent',
      'user_online',
      'user_offline',
      'user-typing',
      'user-stop-typing',
      'message-delivered',
      'messages-read',
    ])
      socket?.off(e);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentId = str(
      ref.watch(authProvider).user?['_id'] ??
          ref.watch(authProvider).user?['id'],
    );
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            avatar(widget.peerName, size: 40),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.peerName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _typing
                      ? 'typing…'
                      : _online
                      ? 'Online'
                      : 'Last seen unavailable',
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CallScreen(
                  peerId: widget.peerId,
                  peerName: widget.peerName,
                  video: false,
                ),
              ),
            ),
            icon: const Icon(Icons.call_outlined),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CallScreen(
                  peerId: widget.peerId,
                  peerName: widget.peerName,
                  video: true,
                ),
              ),
            ),
            icon: const Icon(Icons.videocam_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? ErrorPanel(message: _error!, onRetry: _load)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final sender = message['sender'] is Map
                          ? _map(message['sender'])
                          : {};
                      final mine =
                          str(
                            sender['_id'] ??
                                sender['id'] ??
                                message['senderId'],
                          ) ==
                          currentId;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          constraints: const BoxConstraints(maxWidth: 290),
                          decoration: BoxDecoration(
                            color: mine ? primaryBlue : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(mine ? 18 : 4),
                              bottomRight: Radius.circular(mine ? 4 : 18),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                str(message['message'] ?? message['text']),
                                style: TextStyle(
                                  color: mine ? Colors.white : ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    dateLabel(message['createdAt']),
                                    style: TextStyle(
                                      color: mine ? Colors.white70 : muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                  if (mine)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 5),
                                      child: Icon(
                                        str(
                                                  message['_delivery'] ??
                                                      message['status'],
                                                ) ==
                                                'read'
                                            ? Icons.done_all
                                            : Icons.done_all,
                                        size: 14,
                                        color:
                                            str(
                                                  message['_delivery'] ??
                                                      message['status'],
                                                ) ==
                                                'read'
                                            ? Colors.lightBlueAccent
                                            : Colors.white70,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      onChanged: _typingChange,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Write a message',
                        prefixIcon: Icon(Icons.add_circle_outline),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
