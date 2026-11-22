import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/agent_store.dart';
import '../core/api_client.dart';
import '../core/fmt.dart';
import '../widgets/common.dart';

/// Send an SMS to a customer through the company's gateway and see what this
/// agent has sent recently. Templates and the free-text rule come from the
/// admin's SMS settings on the server.
class SmsScreen extends StatefulWidget {
  const SmsScreen({super.key, this.number = ''});
  final String number;
  @override
  State<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends State<SmsScreen> {
  late final TextEditingController num = TextEditingController(text: widget.number);
  final msg = TextEditingController();
  bool enabled = true, freeText = true, loading = true, sending = false;
  List<Map<String, dynamic>> templates = [];
  List<Map<String, dynamic>> history = [];
  int? templateId;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ApiClient get _api => context.read<AgentStore>().api;

  Future<void> _load() async {
    try {
      final c = await _api.legacyGet('sms/config');
      enabled = c['enabled'] == true;
      freeText = c['free_text'] == true;
      templates = (c['templates'] as List? ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      await _history();
    } on ApiError catch (e) {
      error = e.message;
    } catch (_) {
      error = 'No connection to the server';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _history() async {
    final r = await _api.legacyGet('sms/history');
    history = (r['messages'] as List? ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<void> _send() async {
    setState(() { sending = true; error = null; });
    try {
      await _api.legacyPost('sms/send', {
        'number': num.text.trim(),
        'message': msg.text.trim(),
        if (templateId != null) 'template_id': templateId,
        'context': 'manual',
      });
      msg.clear();
      templateId = null;
      await _history();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SMS sent')));
      }
    } on ApiError catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not send. Check your connection.';
    }
    if (mounted) setState(() => sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: 'SMS',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : !enabled
              ? EmptyState(error ?? 'SMS is not enabled for your company.', icon: Icons.sms_outlined)
              : ListView(padding: const EdgeInsets.all(16), children: [
                  TextField(
                    controller: num,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Customer number', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  if (templates.isNotEmpty)
                    DropdownButtonFormField<int>(
                      initialValue: templateId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Template', border: OutlineInputBorder()),
                      items: [
                        for (final t in templates)
                          DropdownMenuItem(
                              value: int.tryParse('${t['id']}'), child: Text('${t['name']}'))
                      ],
                      onChanged: (v) {
                        setState(() {
                          templateId = v;
                          for (final t in templates) {
                            if (int.tryParse('${t['id']}') == v) msg.text = '${t['body']}';
                          }
                        });
                      },
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: msg,
                    enabled: freeText || templateId == null,
                    readOnly: !freeText,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 1000,
                    decoration: InputDecoration(
                        labelText: freeText ? 'Message' : 'Message (choose a template)',
                        border: const OutlineInputBorder()),
                  ),
                  if (error != null)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(error!, style: const TextStyle(color: Color(0xFFB91C1C)))),
                  FilledButton.icon(
                    onPressed: sending ? null : _send,
                    icon: const Icon(Icons.send),
                    label: Text(sending ? 'Sending…' : 'Send SMS'),
                  ),
                  const SizedBox(height: 20),
                  const Text('Recently sent', style: TextStyle(fontWeight: FontWeight.w800)),
                  if (history.isEmpty)
                    const Padding(padding: EdgeInsets.all(12), child: Text('Nothing sent yet.')),
                  for (final h in history)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                          '${h['status']}' == 'sent' ? Icons.check_circle : Icons.error_outline,
                          color: '${h['status']}' == 'sent'
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626)),
                      title: Text('${h['number']}'),
                      subtitle: Text('${h['message']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Text(fmtWhen('${h['created_at']}'), style: const TextStyle(fontSize: 11)),
                    ),
                ]),
    );
  }
}
