import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    required this.video,
  });
  final String peerId, peerName;
  final bool video;
  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final _local = RTCVideoRenderer(), _remote = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  bool _muted = false,
      _camera = true,
      _speaker = true,
      _connected = false,
      _incoming = false,
      _closed = false;
  String _status = 'Calling…';
  Timer? _timer;
  int _seconds = 0;
  final List<dynamic> _pendingIce = [];
  bool _remoteDescriptionSet = false;
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _local.initialize();
    await _remote.initialize();
    final socket = ref.read(socketProvider);
    if (socket == null) {
      _setStatus('Chat connection is offline');
      return;
    }
    socket.on('incoming-call', _incomingCall);
    socket.on('call-accepted', _accepted);
    socket.on('webrtc-offer', _offer);
    socket.on('webrtc-answer', _answer);
    socket.on('webrtc-ice-candidate', _ice);
    socket.on('call-declined', (_) => _finish('Call declined'));
    socket.on('call-cancelled', (_) => _finish('Call cancelled'));
    socket.on('call-ended', (_) => _finish('Call ended'));
    if (!_incoming) {
      socket.emit('call-user', {
        'targetUserId': widget.peerId,
        'callType': widget.video ? 'video' : 'audio',
        'callerName': widget.peerName,
      });
      await _prepareMedia();
    }
    if (mounted) setState(() {});
  }

  void _setStatus(String value) {
    if (mounted) setState(() => _status = value);
  }

  void _incomingCall(dynamic data) {
    final d = data is Map ? data : {};
    if (str(d['from']) != widget.peerId) return;
    _incoming = true;
    _status = 'Incoming ${str(d['callType'], 'voice')} call';
    if (mounted) setState(() {});
  }

  Future<void> _prepareMedia() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {'echoCancellation': true, 'noiseSuppression': true},
        'video': widget.video
            ? {'facingMode': 'user', 'width': 1280, 'height': 720}
            : false,
      });
      _local.srcObject = _localStream;
      await _setupPeer();
      _setStatus('Ringing…');
    } catch (e) {
      _setStatus('Microphone/camera permission needed');
    }
  }

  Future<void> _setupPeer() async {
    final raw = await ref.read(apiProvider).get('/call/ice-servers');
    final data = raw is Map ? raw : {};
    final servers = data['iceServers'] ?? [];
    _pc = await createPeerConnection({
      'iceServers': servers,
      'iceCandidatePoolSize': 4,
    });
    _pc!.onIceCandidate = (candidate) {
      if (candidate.candidate != null)
        ref.read(socketProvider)?.emit('webrtc-ice-candidate', {
          'targetUserId': widget.peerId,
          'candidate': candidate.toMap(),
        });
    };
    _pc!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _setStatus('Connected');
        _connected = true;
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _seconds++);
        });
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed)
        _setStatus('Connection failed. Check network or TURN setup.');
    };
    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remote.srcObject = event.streams.first;
        if (mounted) setState(() => _connected = true);
      }
    };
    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await _pc!.addTrack(track, _localStream!);
    }
  }

  Future<void> _accepted(dynamic data) async {
    if (str(data is Map ? data['from'] : '') != widget.peerId) return;
    try {
      if (_pc == null) await _prepareMedia();
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      ref.read(socketProvider)?.emit('webrtc-offer', {
        'targetUserId': widget.peerId,
        'description': offer.toMap(),
      });
      _setStatus('Connecting…');
    } catch (e) {
      _setStatus('Could not start call: $e');
    }
  }

  Future<void> _offer(dynamic event) async {
    try {
      final data = event is Map ? event : {};
      if (str(data['from']) != widget.peerId) return;
      if (_pc == null) await _prepareMedia();
      final d = data['description'] as Map;
      await _pc!.setRemoteDescription(
        RTCSessionDescription(str(d['sdp']), str(d['type'])),
      );
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      ref.read(socketProvider)?.emit('webrtc-answer', {
        'targetUserId': widget.peerId,
        'description': answer.toMap(),
      });
      for (final c in _pendingIce) {
        await _pc!.addCandidate(
          RTCIceCandidate(
            str(c['candidate']),
            str(c['sdpMid']),
            c['sdpMLineIndex'] as int?,
          ),
        );
      }
      _pendingIce.clear();
      _setStatus('Connecting…');
    } catch (e) {
      _setStatus('Could not answer call: $e');
    }
  }

  Future<void> _answer(dynamic event) async {
    final data = event is Map ? event : {};
    if (str(data['from']) != widget.peerId || _pc == null) return;
    final d = data['description'] as Map;
    await _pc!.setRemoteDescription(
      RTCSessionDescription(str(d['sdp']), str(d['type'])),
    );
    _remoteDescriptionSet = true;
    for (final c in _pendingIce) {
      await _pc!.addCandidate(
        RTCIceCandidate(
          str(c['candidate']),
          str(c['sdpMid']),
          c['sdpMLineIndex'] as int?,
        ),
      );
    }
    _pendingIce.clear();
  }

  Future<void> _ice(dynamic event) async {
    final data = event is Map ? event : {};
    if (str(data['from']) != widget.peerId) return;
    final c = data['candidate'];
    if (c is! Map) return;
    if (!_remoteDescriptionSet) {
      _pendingIce.add(c);
      return;
    }
    await _pc!.addCandidate(
      RTCIceCandidate(
        str(c['candidate']),
        str(c['sdpMid']),
        c['sdpMLineIndex'] as int?,
      ),
    );
  }

  Future<void> _accept() async {
    if (!_incoming) return;
    try {
      await _prepareMedia();
      ref.read(socketProvider)?.emit('call-accepted', {
        'targetUserId': widget.peerId,
        'callType': widget.video ? 'video' : 'audio',
      });
      _setStatus('Connecting…');
    } catch (e) {
      _setStatus('Could not accept call: $e');
    }
  }

  void _finish(String text) {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    if (mounted) {
      setState(() => _status = text);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  Future<void> _end() async {
    ref.read(socketProvider)?.emit('call-ended', {
      'targetUserId': widget.peerId,
    });
    _finish('Call ended');
    await _disposeMedia();
  }

  Future<void> _disposeMedia() async {
    try {
      await _pc?.close();
      await _localStream?.dispose();
      await _remote.dispose();
      await _local.dispose();
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    final socket = ref.read(socketProvider);
    for (final event in [
      'incoming-call',
      'call-accepted',
      'webrtc-offer',
      'webrtc-answer',
      'webrtc-ice-candidate',
      'call-declined',
      'call-cancelled',
      'call-ended',
    ])
      socket?.off(event);
    _disposeMedia();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final time =
        '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.video && _connected)
            RTCVideoView(
              _remote,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          if (!_connected)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  avatar(
                    widget.peerName,
                    size: 100,
                    color: const Color(0xFF1E2A44),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.peerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_status, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          if (widget.video && _local.srcObject != null)
            Positioned(
              top: 60,
              right: 18,
              width: 110,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: RTCVideoView(
                  _local,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          Positioned(
            bottom: 36,
            left: 20,
            right: 20,
            child: Column(
              children: [
                if (_connected)
                  Text(time, style: const TextStyle(color: Colors.white70)),
                if (_incoming && !_connected) ...[
                  Text(
                    _status,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Control(
                        icon: Icons.call_end,
                        color: Colors.red,
                        onTap: () => _end(),
                      ),
                      const SizedBox(width: 30),
                      _Control(
                        icon: Icons.call,
                        color: Colors.green,
                        onTap: _accept,
                      ),
                    ],
                  ),
                ] else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Control(
                        icon: _muted ? Icons.mic_off : Icons.mic,
                        onTap: () {
                          setState(() => _muted = !_muted);
                          for (final track
                              in _localStream?.getAudioTracks() ??
                                  <MediaStreamTrack>[])
                            track.enabled = !_muted;
                        },
                      ),
                      if (widget.video)
                        _Control(
                          icon: _camera ? Icons.videocam : Icons.videocam_off,
                          onTap: () {
                            setState(() => _camera = !_camera);
                            for (final track
                                in _localStream?.getVideoTracks() ??
                                    <MediaStreamTrack>[])
                              track.enabled = _camera;
                          },
                        ),
                      _Control(
                        icon: _speaker ? Icons.volume_up : Icons.hearing,
                        onTap: () async {
                          setState(() => _speaker = !_speaker);
                          await Helper.setSpeakerphoneOn(_speaker);
                        },
                      ),
                      _Control(
                        icon: Icons.call_end,
                        color: Colors.red,
                        onTap: _end,
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                Text(
                  _connected ? 'Connected' : _status,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({required this.icon, required this.onTap, this.color});
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) => IconButton.filled(
    onPressed: onTap,
    style: IconButton.styleFrom(
      backgroundColor: color ?? Colors.white24,
      foregroundColor: Colors.white,
      fixedSize: const Size(58, 58),
    ),
    icon: Icon(icon),
  );
}
