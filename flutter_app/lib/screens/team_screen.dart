import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/agent_store.dart';
import '../core/session.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key, required this.session});
  final AppSession session;
  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  Rows team = [];
  bool loading = true;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!widget.session.can('team')) { setState(() => loading = false); return; }
    final r = await context.read<AgentStore>().fetchTeam();
    if (mounted) setState(() { team = r; loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.session.can('team')) {
      return const EmptyState('Team view is turned off for your account.', icon: Icons.lock_outline);
    }
    final shown = team.where((t) => '${t['extension']}' != widget.session.extension).toList();
    return Column(children: [
      const ScreenTitle('Team'),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : shown.isEmpty
                ? const EmptyState('No other agents found.', icon: Icons.people_outline)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final t = shown[i];
                        final st = '${t['status']}';
                        final name = '${t['name'] ?? ''}'.trim();
                        final ext = '${t['extension']}';
                        return ListTile(
                          leading: CircleAvatar(child: Text((name.isNotEmpty ? name : ext).substring(0, 1).toUpperCase())),
                          title: Text(name.isNotEmpty ? '$name · $ext' : 'Ext $ext',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Row(children: [
                            Container(width: 8, height: 8,
                                decoration: BoxDecoration(color: statusColor(st), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(statusLabel(st)),
                          ]),
                          trailing: widget.session.can('outbound')
                              ? IconButton(
                                  icon: const Icon(Icons.call, color: BrandTheme.available),
                                  onPressed: st == 'offline' ? null : () => dial(context, ext))
                              : null,
                        );
                      },
                    ),
                  ),
      ),
    ]);
  }
}
