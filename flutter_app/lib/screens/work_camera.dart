import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/agent_store.dart';
import '../core/api_client.dart';
import '../widgets/common.dart';

/// Takes a work photo with the phone camera and sends it to the company. The
/// photo is uploaded straight away and is not kept in the phone's gallery.
class WorkCameraScreen extends StatefulWidget {
  const WorkCameraScreen({super.key});
  @override
  State<WorkCameraScreen> createState() => _WorkCameraScreenState();
}

class _WorkCameraScreenState extends State<WorkCameraScreen> {
  final _picker = ImagePicker();
  final List<String> sent = [];
  bool busy = false;
  String? error;

  Future<void> _take() async {
    setState(() { error = null; });
    try {
      final shot = await _picker.pickImage(
          source: ImageSource.camera, imageQuality: 80, maxWidth: 1920, maxHeight: 1920);
      if (shot == null) return;
      setState(() => busy = true);
      final api = context.read<AgentStore>().api;
      await api.upload('photos', 'photo', shot.path);
      if (mounted) setState(() => sent.insert(0, DateTime.now().toString().substring(11, 16)));
    } on ApiError catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not take or send the photo.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: 'Work photo',
      child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Take a photo for your company. It is sent straight to your supervisor.'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: busy ? null : _take,
          icon: const Icon(Icons.photo_camera),
          label: Text(busy ? 'Sending…' : 'Take photo'),
        ),
        if (error != null)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!, style: const TextStyle(color: Color(0xFFB91C1C)))),
        const SizedBox(height: 20),
        for (final t in sent)
          ListTile(
              dense: true,
              leading: const Icon(Icons.check_circle, color: Color(0xFF16A34A)),
              title: Text('Photo sent at $t')),
      ]),
    );
  }
}
