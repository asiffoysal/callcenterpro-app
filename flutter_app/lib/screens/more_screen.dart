import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/agent_store.dart';
import '../core/session.dart';
import '../widgets/common.dart';
import 'features.dart';

/// The More tab. Each item is gated by a permission, so anything the admin
/// turned off for this agent simply does not appear.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.session, required this.onSignOut});
  final AppSession session;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AgentStore>();
    final items = <(String, IconData, String, WidgetBuilder, int)>[
      ('Callbacks', Icons.history_toggle_off, 'callbacks', (_) => const CallbacksScreen(), store.dueCallbacks),
      ('Queue', Icons.format_list_numbered, 'queue', (_) => const QueueScreen(), 0),
      ('Scripts', Icons.description_outlined, 'scripts', (_) => const ScriptsScreen(), 0),
      ('Phonebook', Icons.menu_book_outlined, 'phonebook', (_) => const PhonebookScreen(), 0),
      ('Notices', Icons.notifications_outlined, 'notices', (_) => const NoticesScreen(), store.unreadNotices),
      ('My summary', Icons.insights_outlined, 'summary', (_) => const SummaryScreen(), 0),
    ].where((e) => session.can(e.$3)).toList();

    Widget card(String label, IconData icon, VoidCallback onTap, int badge) => Card(
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Flexible(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
                if (badge > 0) ...[
                  const Spacer(),
                  CircleAvatar(radius: 10, backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text('$badge', style: const TextStyle(fontSize: 11, color: Colors.white))),
                ],
              ]),
            ),
          ),
        );

    return Column(children: [
      const ScreenTitle('More'),
      Expanded(
        child: GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: [
            for (final (label, icon, _, builder, badge) in items)
              card(label, icon,
                  () => Navigator.push(context, MaterialPageRoute(builder: builder)), badge),
            card('Settings', Icons.settings_outlined, () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SettingsScreen(session: session, onSignOut: onSignOut)));
            }, 0),
          ],
        ),
      ),
    ]);
  }
}
