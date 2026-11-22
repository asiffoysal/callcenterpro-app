import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/agent_store.dart';
import '../core/api_client.dart';
import '../core/fmt.dart';
import '../widgets/common.dart';

/// Team chat: the company-wide room plus one-to-one chats with colleagues.
/// Uses the same server tables as the web agent panel, so messages show up on
/// both sides immediately.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> contacts = [];
  Map<String, dynamic> room = {};
  bool loading = true;
  String? error;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 6), (_) => _load());
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<AgentStore>().api;
    try {
      final r = await api.legacyGet('chat/contacts');
      if (!mounted) return;
      setState(() {
        contacts = (r['contacts'] as List? ?? const [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
        room = (r['room'] as Map?)?.cast<String, dynamic>() ?? {};
        loading = false;
        error = null;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() { loading = false; error = e.message; });
    } catch (_) {
      if (mounted) setState(() { loading = false; error = 'No connection to the server'; });
    }
  }

  void _open(String with_, String name) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ChatThreadScreen(withExt: with_, title: name)));
    _load();
    if (mounted) context.read<AgentStore>().refreshChatUnread();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SubPage(
      title: 'Team chat',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null && contacts.isEmpty
              ? EmptyState(error!, icon: Icons.chat_bubble_outline)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(children: [
                    ListTile(
                      leading: CircleAvatar(
                          backgroundColor: cs.primary,
                          child: const Icon(Icons.groups, color: Colors.white)),
                      title: const Text('Everyone', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        room['last'] is Map
                            ? '${(room['last'] as Map)['from']}: ${(room['last'] as Map)['body']}'
                            : 'Company-wide room',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: _badge(context, room['unread']),
                      onTap: () => _open('*', 'Everyone'),
                    ),
                    const Divider(height: 1),
                    for (final c in contacts)
                      ListTile(
                        leading: Stack(children: [
                          CircleAvatar(
                              backgroundColor: cs.primaryContainer,
                              child: Text('${c['name']}'.isEmpty ? '?' : '${c['name']}'.characters.first.toUpperCase())),
                          Positioned(
                              right: 0, bottom: 0,
                              child: Container(
                                width: 12, height: 12,
                                decoration: BoxDecoration(
                                    color: statusColor('${c['status']}'),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: cs.surface, width: 2)),
                              )),
                        ]),
                        title: Text('${c['name']}  ·  ${c['extension']}'),
                        subtitle: Text(
                          c['last'] is Map ? '${(c['last'] as Map)['body']}' : statusLabel('${c['status']}'),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: _badge(context, c['unread']),
                        onTap: () => _open('${c['extension']}', '${c['name']}'),
                      ),
                  ]),
                ),
    );
  }

  Widget? _badge(BuildContext context, dynamic n) {
    final v = n is int ? n : int.tryParse('$n') ?? 0;
    if (v <= 0) return null;
    return CircleAvatar(
        radius: 11,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Text('$v', style: const TextStyle(fontSize: 11, color: Colors.white)));
  }
}

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({super.key, required this.withExt, required this.title});
  final String withExt;
  final String title;
  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final List<Map<String, dynamic>> msgs = [];
  final text = TextEditingController();
  final scroll = ScrollController();
  Timer? _t;
  int _last = 0;
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _poll();
    _t = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _t?.cancel();
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  ApiClient get _api => context.read<AgentStore>().api;

  Future<void> _poll() async {
    try {
      final r = await _api.legacyGet('chat/messages',
          query: {'with': widget.withExt, 'after': '$_last'});
      final list = (r['messages'] as List? ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      if (list.isNotEmpty && mounted) {
        setState(() {
          msgs.addAll(list);
          final id = list.last['id'];
          _last = id is int ? id : int.tryParse('$id') ?? _last;
          error = null;
        });
        _api.legacyPost('chat/read', {'with': widget.withExt}).catchError((_) => <String, dynamic>{});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {}
  }

  Future<void> _send() async {
    final body = text.text.trim();
    if (body.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await _api.legacyPost('chat/send', {'to': widget.withExt, 'body': body});
      text.clear();
      await _poll();
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not send. Check your connection.')));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _openFile(Map f) async {
    final a = _api;
    final uri = Uri.parse('${a.baseUrl}/api/chat/file').replace(queryParameters: {
      'id': '${f['id']}',
      'tenant_id': '${a.tenantId}',
      'extension': a.extension,
      'agent_token': a.agentToken,
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final me = _api.extension;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(children: [
          if (error != null)
            Container(
                width: double.infinity,
                color: const Color(0xFFFEE2E2),
                padding: const EdgeInsets.all(8),
                child: Text(error!, style: const TextStyle(color: Color(0xFFB91C1C)))),
          Expanded(
            child: msgs.isEmpty
                ? const EmptyState('No messages yet. Say hello!', icon: Icons.chat_bubble_outline)
                : ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) {
                      final m = msgs[i];
                      final mine = '${m['from']}' == me;
                      final f = m['file'] is Map ? m['file'] as Map : null;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                          decoration: BoxDecoration(
                            color: mine ? cs.primary : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (!mine && widget.withExt == '*')
                              Text('Ext ${m['from']}',
                                  style: TextStyle(
                                      fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary)),
                            if ('${m['body']}'.isNotEmpty)
                              Text('${m['body']}',
                                  style: TextStyle(color: mine ? Colors.white : cs.onSurface)),
                            if (f != null)
                              InkWell(
                                onTap: f['gone'] == true ? null : () => _openFile(f),
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                      f['gone'] == true ? '📎 File no longer available' : '📎 ${f['name'] ?? 'File'}',
                                      style: TextStyle(
                                          decoration: TextDecoration.underline,
                                          color: mine ? Colors.white : cs.primary)),
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(fmtClock('${m['time']}'),
                                style: TextStyle(
                                    fontSize: 10,
                                    color: mine ? Colors.white70 : cs.outline)),
                          ]),
                        ),
                      );
                    }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: text,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      hintText: 'Message', counterText: '', border: OutlineInputBorder()),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                  onPressed: sending ? null : _send, icon: const Icon(Icons.send)),
            ]),
          ),
        ]),
      ),
    );
  }
}
