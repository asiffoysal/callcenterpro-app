import 'package:flutter/material.dart';
import '../core/session.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.session});
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(children: [
          CircleAvatar(backgroundColor: cs.primaryContainer, child: const Text('RH')),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Good afternoon', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text('Ext ${session.extension} · ${session.company}',
                  style: TextStyle(color: cs.outline, fontSize: 13)),
            ]),
          ),
          _statusChip('Available', BrandTheme.available),
        ]),
        const SizedBox(height: 16),
        Card(
          child: Column(children: [
            const ListTile(title: Text('Needs attention', style: TextStyle(fontWeight: FontWeight.w700))),
            _attn(context, BrandTheme.onBreak, 'Callback due now', '01819 222 410 · 2:00 PM', 'Call'),
            _attn(context, BrandTheme.dnd, '1 call needs a disposition', 'Dhaka Fabrics Ltd', 'Fill'),
            _attn(context, BrandTheme.onCall, '3 waiting in Sales queue', 'Longest wait 1:42', 'Open'),
          ]),
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF0E1330),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
              _Stat('23', 'Calls'),
              _Stat('1h 42m', 'Talk time'),
              _Stat('92%', 'Success'),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(18)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      );

  Widget _attn(BuildContext context, Color dot, String title, String sub, String action) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(sub),
      trailing: TextButton(onPressed: () {}, child: Text(action)),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]);
}
