import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/agent_store.dart';
import '../core/api_client.dart';
import '../core/session.dart';

/// Blind-transfer the current call to a colleague's extension or any number.
/// Uses the same server transfer the web softphone uses.
Future<bool> showTransferSheet(BuildContext context, AppSession session) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ChangeNotifierProvider<AgentStore>.value(
        value: context.read<AgentStore>(), child: _TransferSheet(session: session)),
  );
  return ok == true;
}

class _TransferSheet extends StatefulWidget {
  const _TransferSheet({required this.session});
  final AppSession session;
  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  final target = TextEditingController();
  List<Map<String, dynamic>> team = [];
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    context.read<AgentStore>().fetchTeam().then((t) {
      if (mounted) setState(() => team = t.where((m) => '${m['extension']}' != widget.session.extension).toList());
    });
  }

  Future<void> _go(String to) async {
    final t = to.trim();
    if (t.isEmpty) return;
    setState(() { busy = true; error = null; });
    try {
      await context.read<AgentStore>().api.legacyPost('transfer/blind', {
        'caller': widget.session.extension,
        'target': t,
        'slug': widget.session.companySlug,
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = 'Transfer failed. Check your connection.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Transfer call', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                  child: TextField(
                      controller: target,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                          labelText: 'Extension or number', border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              FilledButton(onPressed: busy ? null : () => _go(target.text), child: const Text('Transfer')),
            ]),
          ),
          if (error != null)
            Padding(
                padding: const EdgeInsets.all(8),
                child: Text(error!, style: const TextStyle(color: Color(0xFFB91C1C)))),
          const Divider(),
          Expanded(
            child: ListView(children: [
              for (final m in team)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text('${m['name'] ?? m['extension']}'),
                  subtitle: Text('Ext ${m['extension']}  ·  ${m['status']}'),
                  onTap: busy ? null : () => _go('${m['extension']}'),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
