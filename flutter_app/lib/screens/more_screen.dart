import 'package:flutter/material.dart';
import '../core/session.dart';

/// The More tab. Each item is gated by a permission, so anything the admin
/// turned off for this agent simply does not appear.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.session});
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final items = <(String, IconData, String)>[
      ('Callbacks', Icons.history_toggle_off, 'callbacks'),
      ('Queue', Icons.format_list_numbered, 'queue'),
      ('Scripts', Icons.description_outlined, 'scripts'),
      ('Phonebook', Icons.menu_book_outlined, 'phonebook'),
      ('SMS', Icons.sms_outlined, 'sms'),
      ('Notices', Icons.notifications_outlined, 'notices'),
      ('My summary', Icons.insights_outlined, 'summary'),
    ].where((e) => session.can(e.$3)).toList();

    return Column(children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Align(alignment: Alignment.centerLeft,
            child: Text('More', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
      ),
      Expanded(
        child: GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: [
            for (final (label, icon, _) in items)
              Card(
                child: InkWell(
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Icon(icon, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Flexible(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
                    ]),
                  ),
                ),
              ),
            Card(
              child: InkWell(
                onTap: () {},
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(children: [
                    Icon(Icons.settings_outlined),
                    SizedBox(width: 12),
                    Text('Settings', style: TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    ]);
  }
}
