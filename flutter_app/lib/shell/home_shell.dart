import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/session.dart';
import '../core/agent_store.dart';
import '../core/fmt.dart';
import '../widgets/common.dart';
import '../calling/sip_service.dart';
import '../screens/home_screen.dart';
import '../screens/calls_screen.dart';
import '../screens/keypad_screen.dart';
import '../screens/team_screen.dart';
import '../screens/more_screen.dart';
import '../screens/incall_screen.dart';
import '../services/location_reporter.dart';
import '../services/background.dart';

/// The main app shell after sign-in: bottom navigation matching the mockups
/// (Home, Calls, Keypad, Team, More). Each tab keeps its state via IndexedStack.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.session, required this.onSignOut});
  final AppSession session;
  final VoidCallback onSignOut;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  late final SipService _sip;
  late final AgentStore _store;
  LocationReporter? _loc;
  bool _wasRinging = false;

  @override
  void initState() {
    super.initState();
    _sip = context.read<SipService>();
    _store = context.read<AgentStore>();
    _sip.onCallEnded = _handleCallEnded;
    _sip.addListener(_syncPresence);
    Background.start('Ext ${widget.session.extension}');
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLocation());
  }

  @override
  void dispose() {
    _sip.removeListener(_syncPresence);
    _sip.onCallEnded = null;
    _loc?.stop();
    Background.stop();
    super.dispose();
  }

  /// Tells the agent plainly that the company records their position, then
  /// starts sending it. Nothing is sent when the company has it switched off.
  Future<void> _startLocation() async {
    final s = widget.session;
    if (s.locationMode != 'live' && s.locationMode != 'checkin') return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Location sharing'),
        content: Text(s.locationMode == 'live'
            ? '${s.company} records your location while you are signed in to this app. '
                'It stops when you sign out.'
            : '${s.company} records your location when you sign in and after each call.'),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
    if (!mounted) return;
    _loc = LocationReporter(_store.api, s.locationMode)..start();
  }

  void _syncPresence() {
    _store.setInCall(_sip.hasCall);
    final ringing = _sip.hasCall && _sip.incoming && !_sip.connected;
    if (ringing != _wasRinging) {
      _wasRinging = ringing;
      Background.update(ringing
          ? 'Incoming call from ${cleanNumber(_sip.remoteNumber)}'
          : 'Phone line active · Ext ${widget.session.extension}');
    }
  }

  Future<void> _handleCallEnded(EndedCall c) async {
    final peer = cleanNumber(c.peer);
    // Skip logging a call that never really started (e.g. cancelled before ringing).
    if (peer.isEmpty) return;
    await _store.logCall(peer, c.direction, c.status, c.talkSeconds);
    _loc?.sendNow();
    // Ask for a disposition after every answered call, like the web panel.
    if (c.status == 'answered' && mounted) {
      await showDispositionSheet(context, peer: peer, direction: c.direction);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final pages = [
      HomeScreen(session: s),
      CallsScreen(session: s),
      KeypadScreen(session: s),
      TeamScreen(session: s),
      MoreScreen(session: s, onSignOut: widget.onSignOut),
    ];
    final scaffold = Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'Calls'),
          NavigationDestination(icon: Icon(Icons.dialpad), label: 'Keypad'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Team'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
    // Show the call screen over everything whenever there's an active call.
    return Consumer<SipService>(
      builder: (context, sip, _) => Stack(children: [
        scaffold,
        if (sip.hasCall) Positioned.fill(child: InCallScreen(session: s)),
      ]),
    );
  }
}
