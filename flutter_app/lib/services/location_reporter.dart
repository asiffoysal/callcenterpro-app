import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../core/api_client.dart';

/// Sends the agent's position to the company while signed in, according to
/// the company's setting: off, checkin (when signing in and after each call)
/// or live (about once a minute). The agent is shown a notice before the
/// first position is sent.
class LocationReporter {
  LocationReporter(this.api, this.mode);
  final ApiClient api;
  final String mode;
  Timer? _t;

  bool get active => mode == 'live' || mode == 'checkin';

  Future<void> start() async {
    if (!active) return;
    await sendNow();
    if (mode == 'live') {
      _t = Timer.periodic(const Duration(seconds: 60), (_) => sendNow());
    }
  }

  void stop() {
    _t?.cancel();
    _t = null;
  }

  Future<void> sendNow() async {
    if (!active) return;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)));
      await api.post('location', {
        'lat': p.latitude,
        'lng': p.longitude,
        'accuracy': p.accuracy,
      });
    } catch (_) {
      // A missed position is not worth interrupting the agent for.
    }
  }
}
