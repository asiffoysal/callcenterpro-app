import 'package:flutter/foundation.dart';
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
  }

  void stop() {
    try { helper.stop(); } catch (_) {}
  }

  void placeCall(String target) {
    helper.call(target, voiceOnly: true);
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
      _lastError = callState.cause?.toString() ?? '';
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
    if (state.state == RegistrationStateEnum.REGISTRATION_FAILED) {
      _lastError = 'Registration failed: ${state.cause ?? ''}';
    }
    notifyListeners();
  }

  @override
  void transportStateChanged(TransportState state) {
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
