import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Connects to the realtime hub and surfaces tenant events.
/// The hub joins the socket to the tenant's channel using the JWT, so each
/// app only receives its own company's events (theme.update, call.*, queue.*).
class RealtimeClient {
  RealtimeClient({required this.hubUrl, required this.token});
  final String hubUrl; // wss://cc.aitoyes.com/hub
  final String token;

  WebSocketChannel? _ch;
  final _handlers = <String, void Function(Map<String, dynamic>)>{};

  /// Register a handler for an event name, e.g. on('theme.update', ...).
  void on(String event, void Function(Map<String, dynamic> data) handler) {
    _handlers[event] = handler;
  }

  void connect() {
    _ch = WebSocketChannel.connect(Uri.parse('$hubUrl?token=$token'));
    _ch!.stream.listen(
      (msg) {
        try {
          final m = jsonDecode(msg as String) as Map<String, dynamic>;
          final ev = m['event'] as String?;
          final data = (m['data'] as Map?)?.cast<String, dynamic>() ?? {};
          if (ev != null) _handlers[ev]?.call(data);
        } catch (_) {/* ignore malformed frame */}
      },
      onDone: _scheduleReconnect,
      onError: (_) => _scheduleReconnect(),
    );
  }

  bool _reconnecting = false;
  void _scheduleReconnect() {
    if (_reconnecting) return;
    _reconnecting = true;
    Future.delayed(const Duration(seconds: 3), () {
      _reconnecting = false;
      connect();
    });
  }

  void dispose() => _ch?.sink.close();
}
