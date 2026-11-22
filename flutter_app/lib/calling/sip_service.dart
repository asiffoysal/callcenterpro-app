import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_webrtc/flutter_webrtc.dart' show Helper;
import 'package:sip_ua/sip_ua.dart';

/// Wraps the SIP stack and registers the agent's extension to the call engine
/// over WSS (wss://<host>:8089/ws), matching the web softphone. Exposes simple
/// state (registered, in a call, call direction) and actions the UI calls.
/// What happened on a call that just finished; the app uses it to write the
/// call log and to ask the agent for a disposition.
class EndedCall {
  EndedCall(this.peer, this.direction, this.status, this.talkSeconds);
  final String peer;
  final String direction; // inbound | outbound
  final String status; // answered | missed | failed
  final int talkSeconds;
}

class SipService extends ChangeNotifier implements SipUaHelperListener {
  final SIPUAHelper helper = SIPUAHelper();

  bool registered = false;
  Call? _call;
  CallStateEnum _state = CallStateEnum.NONE;
  String remoteNumber = '';
  bool incoming = false;
  bool muted = false;
  bool onHold = false;
  DateTime? _connectedAt;
  bool _wasIncoming = false;
  bool _ended = false;
  String _lastError = '';
  bool speaker = false;
  final List<String> log = [];

  // remembered so we can re-register after a network drop
  String? _host, _sipUser, _password, _display;
  Timer? _watchdog;
  DateTime _lastStart = DateTime.fromMillisecondsSinceEpoch(0);

  void trace(String m) {
    final t = DateTime.now();
    final hh = t.hour.toString().padLeft(2, '0'), mm = t.minute.toString().padLeft(2, '0'), ss = t.second.toString().padLeft(2, '0');
    log.add('$hh:$mm:$ss  $m');
    if (log.length > 400) log.removeAt(0);
    notifyListeners();
  }

  /// Checks that this phone can open a secure connection to the call engine.
  Future<String> testConnection(String host) async {
    try {
      final sw = Stopwatch()..start();
      final sock = await SecureSocket.connect(host, 8089,
          onBadCertificate: (_) => true, timeout: const Duration(seconds: 8));
      final cert = sock.peerCertificate;
      sock.destroy();
      final r = 'Port 8089 on $host is reachable (${sw.elapsedMilliseconds} ms)'
          '${cert != null ? ', certificate: ${cert.subject}' : ''}';
      trace(r);
      return r;
    } catch (e) {
      final r = 'Cannot reach $host:8089 -> $e. The call engine port is closed, blocked by a firewall, or not running.';
      trace(r);
      return r;
    }
  }

  /// Set by the app; called once when each call finishes.
  void Function(EndedCall call)? onCallEnded;
  String get lastError => _lastError;

  CallStateEnum get state => _state;
  bool get hasCall =>
      _call != null && _state != CallStateEnum.ENDED && _state != CallStateEnum.FAILED;
  bool get connected => _state == CallStateEnum.CONFIRMED;
  bool get ringing =>
      _state == CallStateEnum.PROGRESS ||
      _state == CallStateEnum.CALL_INITIATION ||
      _state == CallStateEnum.ACCEPTED;

  /// Register the extension. host is the server domain the agent connected to.
  Future<void> start({
    required String host,
    required String sipUser,
    required String password,
    String? displayName,
    List<Map<String, String>> extraIce = const [],
  }) async {
    _host = host; _sipUser = sipUser; _password = password; _display = displayName;
    _lastStart = DateTime.now();
    trace('Starting phone line: sip:$sipUser@$host via wss://$host:8089/ws');
    final s = UaSettings();
    s.webSocketUrl = 'wss://$host:8089/ws';
    // The call engine's WSS cert on :8089 is often self-signed; tolerate it so
    // mobile can connect (the browser softphone works because the user accepts it).
    s.webSocketSettings.allowBadCertificate = true;
    s.uri = 'sip:$sipUser@$host';
    s.authorizationUser = sipUser;
    s.password = password;
    s.displayName = displayName ?? sipUser;
    s.userAgent = 'CallCenterPro';
    s.dtmfMode = DtmfMode.RFC2833;
    s.register = true;
    s.transportType = TransportType.WS;
    s.iceServers = [
      {'urls': 'stun:stun.l.google.com:19302'},
      ...extraIce,
    ];
    helper.removeSipUaHelperListener(this);
    helper.addSipUaHelperListener(this);
    await helper.start(s);
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 20), (_) => _ensureRegistered());
    testConnection(host); // result goes to the diagnostics log
  }

  /// If the line is not registered (network switched, server restarted) try again.
  void _ensureRegistered() {
    if (registered || hasCall || _host == null) return;
    if (DateTime.now().difference(_lastStart).inSeconds < 20) return;
    trace('Phone line is not registered - reconnecting');
    start(host: _host!, sipUser: _sipUser!, password: _password!, displayName: _display);
  }

  void stop() {
    _watchdog?.cancel();
    _host = null;
    registered = false;
    try { helper.stop(); } catch (_) {}
    trace('Phone line stopped');
  }

  void placeCall(String target) {
    trace('Calling $target');
    helper.call(target, voiceOnly: true);
  }

  void toggleSpeaker() {
    speaker = !speaker;
    try { Helper.setSpeakerphoneOn(speaker); } catch (e) { trace('Speaker: $e'); }
    notifyListeners();
  }

  void answer() {
    _call?.answer(helper.buildCallOptions(true));
  }

  void hangup() {
    _call?.hangup();
  }

  void toggleMute() {
    if (_call == null) return;
    muted = !muted;
    _call!.mute(muted, false);
    notifyListeners();
  }

  void toggleHold() {
    if (_call == null) return;
    onHold ? _call!.unhold() : _call!.hold();
    onHold = !onHold;
    notifyListeners();
  }

  void sendDtmf(String tone) => _call?.sendDTMF(tone);

  // --- SipUaHelperListener ---
  @override
  void callStateChanged(Call call, CallState callState) {
    final prevState = _state;
    trace('Call ${callState.state.name}${callState.cause != null ? ' (${callState.cause?.cause})' : ''}');
    _call = call;
    _state = callState.state;
    incoming = call.direction == Direction.incoming;
    _wasIncoming = incoming;
    final id = call.remote_identity;
    if (id != null && id.isNotEmpty) remoteNumber = id;
    if (_state == CallStateEnum.CALL_INITIATION || _state == CallStateEnum.PROGRESS) {
      _ended = false;
    }
    if (_state == CallStateEnum.CONFIRMED && prevState != CallStateEnum.CONFIRMED) {
      _connectedAt = DateTime.now();
    }
    if (_state == CallStateEnum.FAILED) {
      _lastError = callState.cause?.cause?.toString() ?? '';
    }
    if (_state == CallStateEnum.ENDED || _state == CallStateEnum.FAILED) {
      final talked = _connectedAt == null
          ? 0
          : DateTime.now().difference(_connectedAt!).inSeconds;
      final answered = _connectedAt != null;
      final peer = remoteNumber;
      final dir = _wasIncoming ? 'inbound' : 'outbound';
      _call = null;
      _connectedAt = null;
      speaker = false;
      muted = false;
      onHold = false;
      incoming = false;
      if (!_ended) {
        _ended = true;
        onCallEnded?.call(EndedCall(
          peer, dir,
          answered ? 'answered' : (dir == 'inbound' ? 'missed' : 'failed'),
          talked,
        ));
      }
    }
    notifyListeners();
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    registered = state.state == RegistrationStateEnum.REGISTERED;
    trace('Registration: ${state.state?.name}${state.cause != null ? ' (${state.cause?.cause})' : ''}');
    if (state.state == RegistrationStateEnum.REGISTRATION_FAILED) {
      _lastError = 'Registration failed: ${state.cause?.cause ?? ''}';
    }
    notifyListeners();
  }

  @override
  void transportStateChanged(TransportState state) {
    trace('Connection: ${state.state.name}');
    if (state.state == TransportStateEnum.DISCONNECTED) {
      registered = false;
      notifyListeners();
    }
  }
  @override
  void onNewMessage(SIPMessageRequest msg) {}
  @override
  void onNewNotify(Notify ntf) {}
  @override
  void onNewReinvite(ReInvite event) {}
}
