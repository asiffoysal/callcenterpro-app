import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/agent_store.dart';
import '../core/fmt.dart';
import '../core/session.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// ---------------- Callbacks ----------------
class CallbacksScreen extends StatefulWidget {
  const CallbacksScreen({super.key});
  @override
  State<CallbacksScreen> createState() => _CallbacksScreenState();
}

class _CallbacksScreenState extends State<CallbacksScreen> {
  String filter = 'pending';
  Rows rows = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await context.read<AgentStore>().fetchCallbacks(filter);
    if (mounted) setState(() { rows = r; loading = false; });
  }

  Future<void> _add() async {
    final numCtl = TextEditingController();
    final notes = TextEditingController();
    DateTime when = DateTime.now().add(const Duration(hours: 1));
    final store = context.read<AgentStore>();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('New callback'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: numCtl, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Customer number')),
            TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule),
              label: Text(fmtWhen(sqlStamp(when))),
              onPressed: () async {
                final d = await showDatePicker(
                    context: ctx, initialDate: when,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d == null || !ctx.mounted) return;
                final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(when));
                if (t == null) return;
                setS(() => when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
              onPressed: () async {
                if (numCtl.text.trim().isEmpty) return;
                final ok = await store.addCallback(numCtl.text.trim(), notes.text.trim(), sqlStamp(when));
                if (ctx.mounted) Navigator.pop(ctx);
                if (!ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save the callback.')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AgentStore>();
    return SubPage(
      title: 'Callbacks',
      actions: [IconButton(icon: const Icon(Icons.add), onPressed: _add)],
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pending', label: Text('Pending')),
              ButtonSegment(value: 'completed', label: Text('Done')),
              ButtonSegment(value: 'all', label: Text('All')),
            ],
            selected: {filter},
            onSelectionChanged: (v) { filter = v.first; setState(() => loading = true); _load(); },
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : rows.isEmpty
                  ? const EmptyState('No callbacks here.', icon: Icons.history_toggle_off)
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = rows[i];
                        final id = int.tryParse('${c['id']}') ?? 0;
                        final pending = '${c['status']}' == 'pending';
                        final due = DateTime.tryParse('${c['scheduled_at']}'.replaceFirst(' ', 'T'))
                            ?.isBefore(DateTime.now()) ?? false;
                        return ListTile(
                          leading: Icon(Icons.schedule, color: pending && due ? BrandTheme.dnd : null),
                          title: Text('${c['caller_number']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text([
                            fmtWhen('${c['scheduled_at']}'),
                            if ('${c['notes']}'.isNotEmpty) '${c['notes']}',
                            if (!pending) '${c['status']}',
                          ].join(' · ')),
                          trailing: pending
                              ? Row(mainAxisSize: MainAxisSize.min, children: [
                                  IconButton(
                                      icon: const Icon(Icons.call, color: BrandTheme.available),
                                      onPressed: () => dial(context, '${c['caller_number']}')),
                                  IconButton(
                                      icon: const Icon(Icons.check_circle_outline),
                                      tooltip: 'Mark done',
                                      onPressed: () async { await store.completeCallback(id); _load(); }),
                                  IconButton(
                                      icon: const Icon(Icons.close),
                                      tooltip: 'Cancel',
                                      onPressed: () async { await store.cancelCallback(id); _load(); }),
                                ])
                              : null,
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

/// ---------------- Queue ----------------
class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});
  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  Rows rows = [];
  bool loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final r = await context.read<AgentStore>().fetchQueues();
    if (mounted) setState(() { rows = r; loading = false; });
  }

  @override
  Widget build(BuildContext context) => SubPage(
        title: 'Queues',
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : rows.isEmpty
                ? const EmptyState('No queues set up.', icon: Icons.format_list_numbered)
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (final q in rows)
                        Card(
                          child: ListTile(
                            title: Text('${q['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text([
                              if (q['calls_waiting'] != null) '${q['calls_waiting']} waiting',
                              if (q['available_members'] != null) '${q['available_members']}/${q['total_members']} agents free',
                              if (q['strategy'] != null) '${q['strategy']}',
                            ].join(' · ')),
                            trailing: Text('Ext ${q['extension']}'),
                          ),
                        ),
                    ],
                  ),
      );
}

/// ---------------- Scripts ----------------
class ScriptsScreen extends StatefulWidget {
  const ScriptsScreen({super.key});
  @override
  State<ScriptsScreen> createState() => _ScriptsScreenState();
}

class _ScriptsScreenState extends State<ScriptsScreen> {
  Rows rows = [];
  bool loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final r = await context.read<AgentStore>().fetchScripts();
    if (mounted) setState(() { rows = r; loading = false; });
  }

  @override
  Widget build(BuildContext context) => SubPage(
        title: 'Scripts',
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : rows.isEmpty
                ? const EmptyState('No scripts yet.', icon: Icons.description_outlined)
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (final s in rows)
                        Card(
                          child: ExpansionTile(
                            title: Text('${s['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            expandedCrossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ('${s['opening_greeting']}'.isNotEmpty) ...[
                                const Text('Opening', style: TextStyle(fontWeight: FontWeight.w700)),
                                SelectableText('${s['opening_greeting']}'),
                                const SizedBox(height: 10),
                              ],
                              SelectableText('${s['content']}'),
                              if ('${s['closing_greeting']}'.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                const Text('Closing', style: TextStyle(fontWeight: FontWeight.w700)),
                                SelectableText('${s['closing_greeting']}'),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
      );
}

/// ---------------- Phonebook ----------------
class PhonebookScreen extends StatefulWidget {
  const PhonebookScreen({super.key});
  @override
  State<PhonebookScreen> createState() => _PhonebookScreenState();
}

class _PhonebookScreenState extends State<PhonebookScreen> {
  Rows rows = [];
  bool loading = true;
  final q = TextEditingController();
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final r = await context.read<AgentStore>().fetchPhonebook(q.text.trim());
    if (mounted) setState(() { rows = r; loading = false; });
  }

  @override
  Widget build(BuildContext context) => SubPage(
        title: 'Phonebook',
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: q,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name or number'),
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : rows.isEmpty
                    ? const EmptyState('No contacts found.', icon: Icons.menu_book_outlined)
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) => ListTile(
                          leading: CircleAvatar(child: Text('${rows[i]['name']}'.isEmpty ? '?' : '${rows[i]['name']}'.substring(0, 1).toUpperCase())),
                          title: Text('${rows[i]['name']}'),
                          subtitle: Text('${rows[i]['number']}'),
                          trailing: IconButton(
                              icon: const Icon(Icons.call, color: BrandTheme.available),
                              onPressed: () => dial(context, '${rows[i]['number']}')),
                        ),
                      ),
          ),
        ]),
      );
}

/// ---------------- Notices ----------------
class NoticesScreen extends StatelessWidget {
  const NoticesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AgentStore>();
    final rows = store.notices;
    return SubPage(
      title: 'Notices',
      child: rows.isEmpty
          ? const EmptyState('No notices.', icon: Icons.notifications_none)
          : ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final n = rows[i];
                final unread = '${n['is_read']}' == '0';
                return ListTile(
                  leading: Icon(unread ? Icons.mark_email_unread : Icons.drafts_outlined,
                      color: unread ? Theme.of(context).colorScheme.primary : null),
                  title: Text('${n['title']}', style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w500)),
                  subtitle: Text('${n['message']}'),
                  isThreeLine: true,
                  onTap: () => store.markNoticeRead(int.tryParse('${n['id']}') ?? 0),
                );
              },
            ),
    );
  }
}

/// ---------------- Summary ----------------
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AgentStore>();
    final s = store.summary;
    Widget tile(String label, String value, IconData icon) => Card(
          child: ListTile(leading: Icon(icon), title: Text(label), trailing: Text(value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        );
    return SubPage(
      title: 'My summary (today)',
      child: RefreshIndicator(
        onRefresh: () => store.refreshAll(),
        child: ListView(padding: const EdgeInsets.all(12), children: [
          tile('Total calls', '${s['total'] ?? 0}', Icons.call),
          tile('Inbound', '${s['inbound'] ?? 0}', Icons.call_received),
          tile('Outbound', '${s['outbound'] ?? 0}', Icons.call_made),
          tile('Answered', '${s['answered'] ?? 0}', Icons.check_circle_outline),
          tile('Missed', '${s['missed'] ?? 0}', Icons.call_missed),
          tile('Talk time', fmtDur((s['talk_seconds'] ?? 0) as num), Icons.timer_outlined),
          tile('Break time', fmtDur((s['break_seconds'] ?? 0) as num), Icons.coffee_outlined),
          tile('Pending dispositions', '${s['pending_dispositions'] ?? 0}', Icons.assignment_late_outlined),
          tile('Pending callbacks', '${s['pending_callbacks'] ?? 0}', Icons.history_toggle_off),
        ]),
      ),
    );
  }
}

/// ---------------- Settings ----------------
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.session, required this.onSignOut});
  final AppSession session;
  final VoidCallback onSignOut;
  @override
  Widget build(BuildContext context) => SubPage(
        title: 'Settings',
        child: ListView(children: [
          ListTile(leading: const Icon(Icons.business), title: Text(session.company), subtitle: const Text('Company')),
          ListTile(leading: const Icon(Icons.dialpad), title: Text('Extension ${session.extension}')),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: BrandTheme.dnd),
            title: const Text('Sign out', style: TextStyle(color: BrandTheme.dnd, fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.of(context).popUntil((r) => r.isFirst);
              onSignOut();
            },
          ),
        ]),
      );
}
