import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'session.dart';

typedef Rows = List<Map<String, dynamic>>;

Rows _rows(dynamic v) =>
    (v as List? ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList();

/// Live agent data shared by every screen: presence heartbeat, today's
/// numbers, pending dispositions, callbacks and break state. Everything comes
/// from /app/v1 and is the same data the web agent panel uses.
class AgentStore extends ChangeNotifier {
  AgentStore(this.api, this.session, {this.onSessionExpired, this.onTheme});
  final ApiClient api;
  final AppSession session;
  final VoidCallback? onSessionExpired;
  /// Called with the latest brand theme so the admin's colour change reaches
  /// the app within seconds even without the realtime hub.
  final void Function(Map<String, dynamic> theme)? onTheme;

  Timer? _timer;
  int _tick = 0;
  bool inCall = false;
  int callsRev = 0; // bumps whenever a call is logged so Calls reloads
  String status = 'online'; // online | break | dnd
  String? breakCode;
  DateTime? breakSince;
  String? lastError;

  Map<String, dynamic> summary = {};
  Rows pendingDispositions = [];
  Rows callbacks = [];
  Rows dispositions = [];
  bool skipEnabled = true;
  Rows breakCodes = [];
  Rows notices = [];

  int get unreadNotices => notices.where((n) => '${n['is_read']}' == '0').length;
  int get dueCallbacks {
    final now = DateTime.now();
    return callbacks.where((c) {
      final t = DateTime.tryParse('${c['scheduled_at']}'.replaceFirst(' ', 'T'));
      return t != null && !t.isAfter(now.add(const Duration(minutes: 5)));
    }).length;
  }

  String get effectiveStatus => inCall ? 'in_call' : status;

  void start() {
    _heartbeat();
    refreshAll();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      _tick++;
      _heartbeat();
      if (_tick % 2 == 0) refreshAll(quiet: true); // every 30s
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    // Tell the server we are gone so the team list shows us offline at once.
    api.post('presence', {'status': 'offline'}).catchError((_) => <String, dynamic>{});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<T?> _guard<T>(Future<T> Function() f) async {
    try {
      final r = await f();
      lastError = null;
      return r;
    } on ApiError catch (e) {
      if (e.status == 401) onSessionExpired?.call();
      lastError = e.message;
    } catch (_) {
      lastError = 'No connection to the server';
    }
    return null;
  }

  Future<void> _heartbeat() async {
    await _guard(() => api.post('presence', {'status': effectiveStatus}));
  }

  void setInCall(bool v) {
    if (inCall == v) return;
    inCall = v;
    _heartbeat();
    notifyListeners();
  }

  Future<void> refreshAll({bool quiet = false}) async {
    await Future.wait(<Future<void>>[
      _guard(() async {
        final t = (await api.get('theme'))['theme'];
        if (t is Map) onTheme?.call(t.cast<String, dynamic>());
      }),
      _guard(() async {
        summary = ((await api.get('summary'))['summary'] as Map).cast<String, dynamic>();
      }),
      _guard(() async {
        pendingDispositions = _rows((await api.get('dispositions/pending'))['pending']);
      }),
      if (session.can('callbacks'))
        _guard(() async {
          callbacks = _rows((await api.get('callbacks', query: {'status': 'pending'}))['callbacks']);
        }),
      _guard(() async {
        final r = await api.get('dispositions');
        dispositions = _rows(r['dispositions']);
        skipEnabled = r['skip_enabled'] != false;
      }),
      if (session.can('breaks'))
        _guard(() async {
          final r = await api.get('breakcodes');
          breakCodes = _rows(r['codes']);
          final a = r['active'];
          if (a is Map) {
            status = 'break';
            breakCode = '${a['break_code']}';
            breakSince = DateTime.tryParse('${a['start_time']}'.replaceFirst(' ', 'T'));
          } else if (status == 'break') {
            status = 'online';
            breakCode = null;
            breakSince = null;
          }
        }),
      if (session.can('notices'))
        _guard(() async {
          notices = _rows((await api.get('notices'))['notices']);
        }),
    ]);
    notifyListeners();
  }

  // ---- actions ----
  Future<void> startBreak(String code) async {
    await _guard(() => api.post('break/start', {'code': code}));
    status = 'break';
    breakCode = code;
    breakSince = DateTime.now();
    notifyListeners();
  }

  Future<void> endBreak() async {
    await _guard(() => api.post('break/end'));
    status = 'online';
    breakCode = null;
    breakSince = null;
    notifyListeners();
  }

  Future<void> setDnd(bool on) async {
    if (status == 'break') await endBreak();
    status = on ? 'dnd' : 'online';
    await _heartbeat();
    notifyListeners();
  }

  Future<bool> assignDisposition(int dispositionId,
      {String peer = '', String direction = '', int? cdrId}) async {
    final r = await _guard(() => api.post('dispositions/assign', {
          'disposition_id': dispositionId,
          'peer': peer,
          'direction': direction,
          if (cdrId != null) 'cdr_id': cdrId,
        }));
    refreshAll(quiet: true);
    return r != null;
  }

  Future<void> logCall(String peer, String direction, String status, int duration) async {
    callsRev++;
    await _guard(() => api.post('calls/log', {
          'peer': peer,
          'direction': direction,
          'status': status,
          'duration': duration,
        }));
    refreshAll(quiet: true);
  }

  Future<bool> addCallback(String number, String notes, String when) async {
    final r = await _guard(() => api.post('callbacks',
        {'caller_number': number, 'notes': notes, 'scheduled_at': when}));
    await refreshAll(quiet: true);
    return r != null;
  }

  Future<void> completeCallback(int id) async {
    await _guard(() => api.post('callbacks/complete', {'id': id}));
    await refreshAll(quiet: true);
  }

  Future<void> cancelCallback(int id) async {
    await _guard(() => api.post('callbacks/cancel', {'id': id}));
    await refreshAll(quiet: true);
  }

  Future<void> markNoticeRead(int id) async {
    await _guard(() => api.post('notices/read', {'notice_id': id}));
    for (final n in notices) {
      if ('${n['id']}' == '$id') n['is_read'] = 1;
    }
    notifyListeners();
  }

  // ---- one-off fetches used by screens ----
  Future<Rows> fetchCalls() async =>
      (await _guard(() async => _rows((await api.get('calls'))['calls']))) ?? [];
  Future<Rows> fetchTeam() async =>
      (await _guard(() async => _rows((await api.get('team'))['team']))) ?? [];
  Future<Rows> fetchQueues() async =>
      (await _guard(() async => _rows((await api.get('queue'))['queues']))) ?? [];
  Future<Rows> fetchScripts() async =>
      (await _guard(() async => _rows((await api.get('scripts'))['scripts']))) ?? [];
  Future<Rows> fetchPhonebook(String q) async => (await _guard(() async =>
          _rows((await api.get('phonebook', query: q.isEmpty ? null : {'q': q}))['contacts']))) ??
      [];
  Future<Rows> fetchCallbacks(String status) async => (await _guard(() async =>
          _rows((await api.get('callbacks', query: {'status': status}))['callbacks']))) ??
      [];
}
