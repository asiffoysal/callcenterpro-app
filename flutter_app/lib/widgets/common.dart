import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../calling/sip_service.dart';
import '../core/agent_store.dart';
import '../core/fmt.dart';
import '../theme/app_theme.dart';

/// Start an outbound call from anywhere in the app.
Future<void> dial(BuildContext context, String number) async {
  final n = number.trim();
  if (n.isEmpty) return;
  final sip = context.read<SipService>();
  final msg = ScaffoldMessenger.of(context);
  final st = await Permission.microphone.request();
  if (!st.isGranted) {
    msg.showSnackBar(const SnackBar(content: Text('Microphone permission is needed to make calls.')));
    return;
  }
  if (!sip.registered) {
    msg.showSnackBar(SnackBar(
        content: Text(sip.lastError.isNotEmpty
            ? 'Phone not connected: ${sip.lastError}'
            : 'Phone is still connecting. Try again in a moment.')));
    return;
  }
  sip.placeCall(n);
}

class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
          if (trailing != null) trailing!,
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key, this.icon = Icons.inbox_outlined});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          ]),
        ),
      );
}

/// A scaffold used by every secondary page opened from More.
class SubPage extends StatelessWidget {
  const SubPage({super.key, required this.title, required this.child, this.actions});
  final String title;
  final Widget child;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: SafeArea(child: child),
      );
}

Color statusColor(String s) => switch (s) {
      'online' => BrandTheme.available,
      'in_call' => BrandTheme.onCall,
      'break' => BrandTheme.onBreak,
      'dnd' => BrandTheme.dnd,
      _ => BrandTheme.offline,
    };

String statusLabel(String s) => switch (s) {
      'online' => 'Available',
      'in_call' => 'On call',
      'break' => 'Break',
      'dnd' => 'Do not disturb',
      _ => 'Offline',
    };

/// Bottom sheet asking the agent to pick a disposition for a finished call.
Future<void> showDispositionSheet(BuildContext context,
    {required String peer, required String direction, int? cdrId}) async {
  final store = context.read<AgentStore>();
  if (store.dispositions.isEmpty) await store.refreshAll(quiet: true);
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: store.skipEnabled,
    enableDrag: store.skipEnabled,
    showDragHandle: true,
    builder: (ctx) => _DispositionSheet(
        store: store, peer: peer, direction: direction, cdrId: cdrId),
  );
}

class _DispositionSheet extends StatefulWidget {
  const _DispositionSheet(
      {required this.store, required this.peer, required this.direction, this.cdrId});
  final AgentStore store;
  final String peer, direction;
  final int? cdrId;
  @override
  State<_DispositionSheet> createState() => _DispositionSheetState();
}

class _DispositionSheetState extends State<_DispositionSheet> {
  bool saving = false;

  Future<void> _pick(Map<String, dynamic> d) async {
    setState(() => saving = true);
    final id = int.tryParse('${d['id']}') ?? 0;
    final ok = await widget.store.assignDisposition(id,
        peer: widget.peer, direction: widget.direction, cdrId: widget.cdrId);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not save. Check your connection and try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = widget.store.dispositions;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('How did the call go?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(widget.peer.isEmpty ? 'Select a disposition' : widget.peer,
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        const SizedBox(height: 14),
        if (ds.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('No dispositions are set up for your company.'))
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final d in ds)
              ActionChip(
                avatar: CircleAvatar(radius: 6, backgroundColor: _hex('${d['color']}')),
                label: Text('${d['name']}'),
                onPressed: saving ? null : () => _pick(d),
              ),
          ]),
        if (widget.store.skipEnabled) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Skip for now')),
          ),
        ],
      ]),
    );
  }

  Color _hex(String s) {
    s = s.replaceFirst('#', '');
    if (s.length == 6) s = 'FF$s';
    return Color(int.tryParse(s, radix: 16) ?? 0xFF6366F1);
  }
}

String callTitle(Map<String, dynamic> c) => cleanNumber('${c['peer_number'] ?? ''}');
