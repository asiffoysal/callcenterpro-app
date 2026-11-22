import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/agent_store.dart';
import '../core/api_client.dart';
import '../core/fmt.dart';
import '../widgets/common.dart';

/// This agent's own call recordings. Tapping one opens it in the phone's
/// audio player.
class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});
  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AgentStore>().api;
    try {
      final r = await api.legacyGet('recordings/list',
          query: {'extension': api.extension, 'per_page': '60'});
      rows = (r['recordings'] as List? ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    } on ApiError catch (e) {
      error = e.message;
    } catch (_) {
      error = 'No connection to the server';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _play(Map<String, dynamic> r) async {
    final api = context.read<AgentStore>().api;
    await launchUrl(Uri.parse('${api.baseUrl}${r['url']}'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: 'Recordings',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
              ? EmptyState(error ?? 'No recordings yet.', icon: Icons.mic_none)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final r = rows[i];
                      return ListTile(
                        leading: const Icon(Icons.play_circle_outline),
                        title: Text('${r['caller'] ?? ''}'.isEmpty ? '${r['filename']}' : '${r['caller']}'),
                        subtitle: Text('${fmtWhen('${r['mtime']}')}  ·  ${r['direction'] ?? ''}'),
                        trailing: Text(fmtDur(num.tryParse('${r['duration']}') ?? 0)),
                        onTap: () => _play(r),
                      );
                    },
                  ),
                ),
    );
  }
}
