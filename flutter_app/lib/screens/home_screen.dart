import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../calling/sip_service.dart';
import '../core/agent_store.dart';
import '../core/fmt.dart';
import '../core/session.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'features.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.session});
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AgentStore>();
    final sip = context.watch<SipService>();
    final cs = Theme.of(context).colorScheme;
    final s = store.summary;
    final st = store.effectiveStatus;
    final hour = DateTime.now().hour;
    final greet = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final pend = store.pendingDispositions;
    final cbDue = store.dueCallbacks;

    return RefreshIndicator(
      onRefresh: () => store.refreshAll(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(children: [
            CircleAvatar(backgroundColor: cs.primaryContainer, child: Text(session.extension.length >= 2
                ? session.extension.substring(session.extension.length - 2) : session.extension)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(greet, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text('Ext ${session.extension} · ${session.company}',
                    style: TextStyle(color: cs.outline, fontSize: 13)),
              ]),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _statusSheet(context, store),
              child: _chip(statusLabel(st), statusColor(st)),
            ),
          ]),
          const SizedBox(height: 10),
          _phoneLine(context, sip),
          const SizedBox(height: 10),
          Card(
            child: Column(children: [
              const ListTile(title: Text('Needs attention', style: TextStyle(fontWeight: FontWeight.w700))),
              if (cbDue > 0)
                _attn(BrandTheme.onBreak, '$cbDue callback${cbDue > 1 ? 's' : ''} due',
                    'Tap to open your callbacks', 'Open',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CallbacksScreen()))),
              if (pend.isNotEmpty)
                _attn(BrandTheme.dnd, '${pend.length} call${pend.length > 1 ? 's' : ''} need a disposition',
                    cleanNumber('${pend.first['peer_number']}'), 'Fill', () async {
                  final p = pend.first;
                  await showDispositionSheet(context,
                      peer: cleanNumber('${p['peer_number']}'),
                      direction: '${p['direction']}',
                      cdrId: int.tryParse('${p['id']}'));
                }),
              if (store.unreadNotices > 0)
                _attn(BrandTheme.onCall, '${store.unreadNotices} unread notice${store.unreadNotices > 1 ? 's' : ''}',
                    'From your company', 'Read',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticesScreen()))),
              if (cbDue == 0 && pend.isEmpty && store.unreadNotices == 0)
                const ListTile(
                  leading: Icon(Icons.check_circle, color: BrandTheme.available),
                  title: Text('All caught up'),
                  subtitle: Text('Nothing is waiting for you.'),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF0E1330),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _Stat('${s['total'] ?? 0}', 'Calls today'),
                _Stat(fmtDur((s['talk_seconds'] ?? 0) as num), 'Talk time'),
                _Stat('${s['answered'] ?? 0}', 'Answered'),
                _Stat('${s['missed'] ?? 0}', 'Missed'),
              ]),
            ),
          ),
          if (store.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(store.lastError!, style: const TextStyle(color: BrandTheme.dnd, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _phoneLine(BuildContext context, SipService sip) {
    final ok = sip.registered;
    final c = ok ? BrandTheme.available : BrandTheme.onBreak;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: c.withOpacity(.10), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(ok ? Icons.phone_in_talk : Icons.sync, size: 18, color: c),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
              ok ? 'Phone line connected' : (sip.lastError.isNotEmpty ? 'Phone line: ${sip.lastError}' : 'Connecting phone line…'),
              style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ]),
    );
  }

  void _statusSheet(BuildContext context, AgentStore store) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.circle, color: BrandTheme.available),
            title: const Text('Available'),
            onTap: () async {
              Navigator.pop(ctx);
              if (store.status == 'break') { await store.endBreak(); } else { await store.setDnd(false); }
            },
          ),
          ListTile(
            leading: const Icon(Icons.circle, color: BrandTheme.dnd),
            title: const Text('Do not disturb'),
            onTap: () { Navigator.pop(ctx); store.setDnd(true); },
          ),
          if (store.breakCodes.isNotEmpty) const Divider(),
          for (final b in store.breakCodes)
            ListTile(
              leading: const Icon(Icons.coffee_outlined, color: BrandTheme.onBreak),
              title: Text('Break · ${b['label']}'),
              onTap: () { Navigator.pop(ctx); store.startBreak('${b['code']}'); },
            ),
        ]),
      ),
    );
  }

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(18)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 13)),
          Icon(Icons.arrow_drop_down, size: 18, color: c),
        ]),
      );

  Widget _attn(Color dot, String title, String sub, String action, VoidCallback onTap) => ListTile(
        leading: Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(sub),
        trailing: TextButton(onPressed: onTap, child: Text(action)),
      );
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]);
}
