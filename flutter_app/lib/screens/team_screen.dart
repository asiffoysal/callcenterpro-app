import 'package:flutter/material.dart';
import '../core/session.dart';
import '../theme/app_theme.dart';

class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key, required this.session});
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final team = [
      ('Nusrat Jahan', '1002', 'Available', BrandTheme.available),
      ('Imran Kabir', '1005', 'Available', BrandTheme.available),
      ('Tanvir Ahmed', '1003', 'On call', BrandTheme.onCall),
      ('Sadia Rahman', '1004', 'Break', BrandTheme.onBreak),
      ('Farhana Akter', '1006', 'DND', BrandTheme.dnd),
      ('Mehedi Hasan', '1007', 'Offline', BrandTheme.offline),
    ];
    return Column(children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Align(alignment: Alignment.centerLeft,
            child: Text('Team', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: team.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final (name, ext, status, color) = team[i];
            return ListTile(
              leading: CircleAvatar(child: Text(name.substring(0, 1))),
              title: Text('$name · $ext', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(status),
              ]),
              trailing: IconButton(icon: const Icon(Icons.call, color: BrandTheme.available), onPressed: () {}),
            );
          },
        ),
      ),
    ]);
  }
}
