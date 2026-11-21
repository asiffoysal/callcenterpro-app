import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/session.dart';
import '../calling/sip_service.dart';
import '../screens/home_screen.dart';
import '../screens/calls_screen.dart';
import '../screens/keypad_screen.dart';
import '../screens/team_screen.dart';
import '../screens/more_screen.dart';
import '../screens/incall_screen.dart';

/// The main app shell after sign-in: bottom navigation matching the mockups
/// (Home, Calls, Keypad, Team, More). Each tab keeps its state via IndexedStack.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.session});
  final AppSession session;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final pages = [
      HomeScreen(session: s),
      CallsScreen(session: s),
      KeypadScreen(session: s),
      TeamScreen(session: s),
      MoreScreen(session: s),
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
        if (sip.hasCall) const Positioned.fill(child: InCallScreen()),
      ]),
    );
  }
}
