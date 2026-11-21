import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/agent_store.dart';
import '../core/fmt.dart';
import '../core/session.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key, required this.session});
  final AppSession session;
  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  Rows rows = [];
  bool loading = true;
  int _seenRev = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await context.read<AgentStore>().fetchCalls();
    if (mounted) setState(() { rows = r; loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    // Reload whenever the store reports new data (e.g. a call just ended).
    final rev = context.select<AgentStore, int>((s) => s.callsRev);
    if (rev != _seenRev) {
      _seenRev = rev;
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
    }
    return Column(children: [
      ScreenTitle('Calls', trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: _load)),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : rows.isEmpty
                ? const EmptyState('No calls yet. Your calls will appear here.', icon: Icons.history)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => _tile(context, rows[i]),
                    ),
                  ),
      ),
    ]);
  }

  Widget _tile(BuildContext context, Map<String, dynamic> c) {
    final dir = '${c['direction']}';
    final status = '${c['status']}';
    final miss = dir == 'inbound' && status != 'answered' && status != 'completed' && status != 'connected';
    final color = miss ? BrandTheme.dnd : (dir == 'outbound' ? BrandTheme.onCall : BrandTheme.available);
    final icon = miss ? Icons.call_missed : (dir == 'outbound' ? Icons.call_made : Icons.call_received);
    final dur = int.tryParse('${c['duration'] ?? ''}');
    final disp = '${c['disposition'] ?? ''}';
    final meta = [
      miss ? 'Missed' : (dir == 'outbound' ? 'Outbound' : 'Inbound'),
      fmtWhen('${c['timestamp']}'),
      if (dur != null && dur > 0) fmtDur(dur),
      if (disp.isNotEmpty) disp,
    ].join(' · ');
    final number = callTitle(c);
    return ListTile(
      leading: CircleAvatar(backgroundColor: color.withOpacity(.12), child: Icon(icon, color: color, size: 18)),
      title: Text(number.isEmpty ? 'Unknown' : number,
          style: TextStyle(fontWeight: FontWeight.w600, color: miss ? BrandTheme.dnd : null)),
      subtitle: Text(meta),
      trailing: widget.session.can('outbound')
          ? IconButton(
              icon: const Icon(Icons.call, color: BrandTheme.available), onPressed: () => dial(context, number))
          : null,
    );
  }
}
