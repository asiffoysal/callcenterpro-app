import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sip_ua/sip_ua.dart';
import '../calling/sip_service.dart';
import '../core/agent_store.dart';
import '../core/fmt.dart';
import '../core/session.dart';
import 'crm_form.dart';
import 'transfer_sheet.dart';

/// Full-screen call UI shown (as an overlay) whenever there is an active call,
/// for both incoming and outgoing. Reads live state from SipService.
class InCallScreen extends StatefulWidget {
  const InCallScreen({super.key, required this.session});
  final AppSession session;
  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  Map<String, dynamic>? form;
  String _lookedUp = '';
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Re-draw once a second so the call timer counts up.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  /// Once we know who is on the line, ask the server whether the company has
  /// a customer-info form for this call.
  void _lookup(SipService sip) {
    if (!widget.session.can('crm_forms')) return;
    final peer = cleanNumber(sip.remoteNumber);
    if (peer.isEmpty || peer == _lookedUp) return;
    _lookedUp = peer;
    final dir = sip.incoming ? 'inbound' : 'outbound';
    lookupCallForm(context.read<AgentStore>().api, peer, dir).then((f) {
      if (mounted) setState(() => form = f);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sip = context.watch<SipService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _lookup(sip);
    });
    final incomingRinging = sip.incoming && sip.state == CallStateEnum.PROGRESS;

    String status;
    if (sip.connected) {
      status = 'In call  ·  ${fmtClock2(sip.talkSeconds)}';
    } else if (incomingRinging) {
      status = 'Incoming call';
    } else if (sip.ringing) {
      status = 'Calling…';
    } else {
      status = '';
    }

    return Material(
      color: const Color(0xFF0E1330),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 36),
          child: Column(children: [
            Text(status, style: const TextStyle(color: Color(0xFFA3A9D1), fontSize: 14)),
            const SizedBox(height: 40),
            CircleAvatar(
              radius: 52,
              backgroundColor: const Color(0xFF232A55),
              child: Text(
                (sip.remoteNumber.isNotEmpty ? sip.remoteNumber.characters.first : '?').toUpperCase(),
                style: const TextStyle(color: Color(0xFFA5B4FC), fontSize: 40, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 20),
            Text(sip.remoteNumber.isEmpty ? 'Unknown' : sip.remoteNumber,
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (sip.connected || sip.ringing)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Wrap(spacing: 10, children: [
                  if (form != null)
                    ActionChip(
                      avatar: const Icon(Icons.assignment_outlined, size: 18),
                      label: const Text('Client info'),
                      onPressed: () => showCallFormSheet(context,
                          form: form!,
                          peer: cleanNumber(sip.remoteNumber),
                          direction: sip.incoming ? 'inbound' : 'outbound'),
                    ),
                  if (sip.connected && widget.session.can('transfer'))
                    ActionChip(
                      avatar: const Icon(Icons.phone_forwarded, size: 18),
                      label: const Text('Transfer'),
                      onPressed: () => showTransferSheet(context, widget.session),
                    ),
                ]),
              ),
            if (sip.connected)
              Wrap(spacing: 28, runSpacing: 20, alignment: WrapAlignment.center, children: [
                _round(context, sip.muted ? Icons.mic_off : Icons.mic, sip.muted ? 'Unmute' : 'Mute',
                    () => context.read<SipService>().toggleMute(), active: sip.muted),
                _round(context, Icons.pause, sip.onHold ? 'Resume' : 'Hold',
                    () => context.read<SipService>().toggleHold(), active: sip.onHold),
                _round(context, Icons.volume_up, 'Speaker', () => context.read<SipService>().toggleSpeaker(), active: sip.speaker),
              ]),
            const SizedBox(height: 28),
            if (incomingRinging)
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _bigButton(Icons.call_end, const Color(0xFFDC2626), 'Decline',
                    () => context.read<SipService>().hangup()),
                _bigButton(Icons.call, const Color(0xFF16A34A), 'Answer',
                    () => context.read<SipService>().answer()),
              ])
            else
              _bigButton(Icons.call_end, const Color(0xFFDC2626), 'End',
                  () => context.read<SipService>().hangup()),
          ]),
        ),
      ),
    );
  }

  Widget _round(BuildContext c, IconData icon, String label, VoidCallback onTap, {bool active = false}) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: active ? Colors.white : const Color(0xFF232A55),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: active ? const Color(0xFF0E1330) : Colors.white),
        ),
      ),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: Color(0xFFC9CDEA), fontSize: 13)),
    ]);
  }

  Widget _bigButton(IconData icon, Color color, String label, VoidCallback onTap) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 74, height: 74,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
      ),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: Color(0xFFC9CDEA), fontSize: 14)),
    ]);
  }
}

String fmtClock2(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
