import 'package:flutter/material.dart';
import '../core/server_config.dart';

/// First-run screen: set which server this app connects to. Shown until a
/// server is saved; reachable later via "Change server" on the login screen.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key, required this.onConnected});
  final VoidCallback onConnected;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _addr = TextEditingController(text: ServerConfig.baseUrl ?? '');
  String? _error;

  Future<void> _save() async {
    final v = _addr.text.trim();
    if (v.isEmpty || v.length < 4) {
      setState(() => _error = 'Enter your server address');
      return;
    }
    await ServerConfig.save(v);
    widget.onConnected();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.dns_outlined, size: 48, color: cs.primary),
            const SizedBox(height: 14),
            const Text('Connect to your server',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Enter the address your company gave you. You only do this once.',
                textAlign: TextAlign.center, style: TextStyle(color: cs.outline)),
            const SizedBox(height: 24),
            TextField(
              controller: _addr,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Server address',
                hintText: 'e.g. cc.yourcompany.com',
                errorText: _error,
                prefixIcon: const Icon(Icons.link),
              ),
              onChanged: (_) { if (_error != null) setState(() => _error = null); },
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Continue')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {}, // QR scanning is added with the camera stage
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR from your admin'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ]),
        ),
      ),
    );
  }
}
