import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/agent_store.dart';
import '../core/api_client.dart';

/// Looks up the company's customer-info form for a call. Returns null when the
/// company has no form (or the form does not apply to this call).
Future<Map<String, dynamic>?> lookupCallForm(
    ApiClient api, String peer, String direction) async {
  try {
    final r = await api.legacyGet('forms/check-caller',
        query: {'caller_number': peer, 'direction': direction});
    final f = r['form'];
    if (r['has_previous_call'] == true && f is Map) return f.cast<String, dynamic>();
  } catch (_) {}
  return null;
}

List<String> _options(dynamic raw) => ('${raw ?? ''}')
    .split('\n')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

String _fieldName(Map f, int i) {
  final n = '${f['name'] ?? ''}';
  return n.isNotEmpty ? n : 'field_$i';
}

/// Opens the customer-info form as a tall bottom sheet. Works for the three
/// form kinds the admin can create: normal builder forms, CRM API forms
/// (pre-filled from the CRM, saved back to it) and iframe forms.
Future<void> showCallFormSheet(BuildContext context,
    {required Map<String, dynamic> form, required String peer, required String direction}) async {
  final api = context.read<AgentStore>().api;
  final type = '${form['form_type'] ?? 'builder'}';

  if (type == 'iframe') {
    try {
      final r = await api.legacyGet('crm/iframe-url',
          query: {'form_id': '${form['id']}', 'caller_number': peer, 'direction': direction});
      final url = '${r['url']}';
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on ApiError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    return;
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ChangeNotifierProvider<AgentStore>.value(
      value: context.read<AgentStore>(),
      child: _CallFormSheet(form: form, peer: peer, direction: direction, isApi: type == 'api'),
    ),
  );
}

class _CallFormSheet extends StatefulWidget {
  const _CallFormSheet(
      {required this.form, required this.peer, required this.direction, required this.isApi});
  final Map<String, dynamic> form;
  final String peer;
  final String direction;
  final bool isApi;
  @override
  State<_CallFormSheet> createState() => _CallFormSheetState();
}

class _CallFormSheetState extends State<_CallFormSheet> {
  final Map<String, String> values = {};
  final Map<String, TextEditingController> ctl = {};
  bool saving = false;
  bool loadingCrm = false;
  String? error;
  String? crmNote;

  List<Map<String, dynamic>> get fields => (widget.form['fields'] as List? ?? const [])
      .map((e) => (e as Map).cast<String, dynamic>())
      .toList();

  @override
  void initState() {
    super.initState();
    if (widget.isApi && widget.form['crm_fetch'] == true) _prefill();
  }

  @override
  void dispose() {
    for (final c in ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _prefill() async {
    setState(() => loadingCrm = true);
    try {
      final api = context.read<AgentStore>().api;
      final r = await api.legacyGet('crm/fetch', query: {
        'form_id': '${widget.form['id']}',
        'caller_number': widget.peer,
        'direction': widget.direction,
      });
      final data = r['data'];
      if (data is Map && r['found'] == true) {
        data.forEach((k, v) {
          values['$k'] = '$v';
          ctl['$k']?.text = '$v';
        });
        crmNote = 'Customer details loaded from the CRM.';
      } else if (r['error'] != null) {
        crmNote = 'CRM lookup failed: ${r['error']}';
      } else {
        crmNote = 'No matching customer found in the CRM.';
      }
    } catch (_) {
      crmNote = 'CRM lookup failed.';
    }
    if (mounted) setState(() => loadingCrm = false);
  }

  Future<void> _submit() async {
    final fl = fields;
    for (var i = 0; i < fl.length; i++) {
      final f = fl[i];
      final name = _fieldName(f, i);
      final v = (values[name] ?? '').trim();
      if (f['required'] == true && v.isEmpty) {
        setState(() => error = '${f['label'] ?? name} is required');
        return;
      }
    }
    setState(() { saving = true; error = null; });
    final api = context.read<AgentStore>().api;
    final data = <String, dynamic>{};
    for (var i = 0; i < fl.length; i++) {
      final n = _fieldName(fl[i], i);
      data[n] = (values[n] ?? '').trim();
    }
    try {
      if (widget.isApi) {
        await api.legacyPost('crm/submit', {
          'form_id': widget.form['id'],
          'caller_number': widget.peer,
          'direction': widget.direction,
          'data': data,
        });
      } else {
        await api.legacyPost('forms/submit', {
          'form_id': widget.form['id'],
          'caller_number': widget.peer,
          'direction': widget.direction,
          'data': data,
        });
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Client info saved')));
    } on ApiError catch (e) {
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = 'Could not save. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _field(Map<String, dynamic> f, int i) {
    final name = _fieldName(f, i);
    final label = '${f['label'] ?? f['name'] ?? 'Field'}${f['required'] == true ? ' *' : ''}';
    final type = '${f['type'] ?? 'text'}';
    final opts = _options(f['options']);
    switch (type) {
      case 'select':
        final cur = values[name];
        return DropdownButtonFormField<String>(
          initialValue: opts.contains(cur) ? cur : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          items: [for (final o in opts) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: (v) => setState(() => values[name] = v ?? ''),
        );
      case 'radio':
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          for (final o in opts)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(values[name] == o
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              title: Text(o),
              onTap: () => setState(() => values[name] = o),
            ),
        ]);
      case 'checkbox':
        final chosen = (values[name] ?? '').split(', ').where((e) => e.isNotEmpty).toSet();
        final list = opts.isEmpty ? ['1'] : opts;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          for (final o in list)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(opts.isEmpty ? 'Yes' : o),
              value: chosen.contains(o),
              onChanged: (v) => setState(() {
                if (v == true) {
                  chosen.add(o);
                } else {
                  chosen.remove(o);
                }
                values[name] = chosen.join(', ');
              }),
            ),
        ]);
      default:
        final c = ctl.putIfAbsent(name, () => TextEditingController(text: values[name] ?? ''));
        return TextField(
          controller: c,
          onChanged: (v) => values[name] = v,
          minLines: type == 'textarea' ? 3 : 1,
          maxLines: type == 'textarea' ? 6 : 1,
          keyboardType: switch (type) {
            'number' => TextInputType.number,
            'email' => TextInputType.emailAddress,
            'tel' => TextInputType.phone,
            'textarea' => TextInputType.multiline,
            _ => TextInputType.text,
          },
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fl = fields;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${widget.form['name'] ?? 'Client info'}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text('${widget.direction == 'outbound' ? 'To' : 'From'} ${widget.peer}',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline)),
              ]),
            ),
            if (loadingCrm)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
        ),
        if (crmNote != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(alignment: Alignment.centerLeft, child: Text(crmNote!, style: const TextStyle(fontSize: 12))),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: fl.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _field(fl[i], i),
          ),
        ),
        if (error != null)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(error!, style: const TextStyle(color: Color(0xFFB91C1C)))),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
                onPressed: saving ? null : _submit,
                child: Text(saving ? 'Saving…' : 'Save client info')),
          ),
        ),
      ]),
    );
  }
}
