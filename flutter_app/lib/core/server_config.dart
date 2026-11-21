import 'package:shared_preferences/shared_preferences.dart';

/// The server the app talks to. Set once at setup time (typed by the agent or
/// scanned from the admin's QR) and saved on the device. NOTHING is hardcoded,
/// so the same app works for every company on its own server/domain/IP.
class ServerConfig {
  static String? baseUrl; // e.g. https://cc.example.com  or  http://203.0.113.4
  static const _key = 'server_base';

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    baseUrl = p.getString(_key);
  }

  /// Normalise and save. Adds https:// if the scheme is missing and trims a
  /// trailing slash, so agents can type "cc.example.com" or a full URL.
  static Future<void> save(String url) async {
    url = url.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    baseUrl = url;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, url);
  }

  static Future<void> clear() async {
    baseUrl = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }

  static bool get isSet => baseUrl != null && baseUrl!.isNotEmpty;

  /// WebSocket address for the realtime hub, derived from the base URL
  /// (https -> wss, http -> ws).
  static String get hubUrl => '${(baseUrl ?? '').replaceFirst('http', 'ws')}/hub';
}
