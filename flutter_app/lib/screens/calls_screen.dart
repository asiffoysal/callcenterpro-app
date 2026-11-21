import 'package:flutter/material.dart';
import '../core/session.dart';
import '../theme/app_theme.dart';

class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key, required this.session});
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('in', 'Karim Traders', 'Inbound · 2:14 PM · 6m 12s'),
      ('miss', '01819 222 410', 'Missed · 1:58 PM · Sales queue'),
      ('out', 'Nusrat Jahan', 'Outbound · 1:30 PM · 3m 40s'),
      ('in', 'Dhaka Fabrics Ltd', 'Inbound · 12:05 PM · 9m 02s'),
    ];
    return Column(children: [
      const _Header('Calls'),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final (kind, name, meta) = rows[i];
            final miss = kind == 'miss';
            final color = miss ? BrandTheme.dnd : (kind == 'out' ? BrandTheme.onCall : BrandTheme.available);
            final icon = miss ? Icons.call_missed : (kind == 'out' ? Icons.call_made : Icons.call_received);
            return ListTile(
              leading: CircleAvatar(backgroundColor: color.withOpacity(.12), child: Icon(icon, color: color, size: 18)),
              title: Text(name, style: TextStyle(fontWeight: FontWeight.w600, color: miss ? BrandTheme.dnd : null)),
              subtitle: Text(meta),
              trailing: IconButton(icon: const Icon(Icons.call, color: BrandTheme.available), onPressed: () {}),
            );
          },
        ),
      ),
    ]);
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Align(alignment: Alignment.centerLeft,
            child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
      );
}
