import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Thin REST client for the /app/v1 API.
/// baseUrl is your server, e.g. https://cc.aitoyes.com
class ApiClient {
  ApiClient(this.baseUrl, {this.token});
  final String baseUrl;
  String? token;

  // Tolerate a self-signed certificate on the call center server so the app
  // can connect for testing. For production, install a real certificate
  // (Let's Encrypt) and this simply has no effect.
  static final http.Client _client = IOClient(
    HttpClient()..badCertificateCallback = (cert, host, port) => true,
  );

  Uri _u(String path) => Uri.parse('$baseUrl/app/v1/$path');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (token != null) 'X-App-Token': token!,
      };

  Future<Map<String, dynamic>> login({
    required String company,
    required String extension,
    required String password,
    Map<String, dynamic>? device,
  }) async {
    final res = await _client.post(_u('login'),
        headers: _headers,
        body: jsonEncode({
          'company': company,
          'extension': extension,
          'password': password,
          if (device != null) 'device': device,
        }));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw ApiError(body['error']?.toString() ?? 'Sign-in failed', res.statusCode);
    }
    token = body['token'] as String?;
    return body;
  }

  Future<Map<String, dynamic>> bootstrap() async {
    final res = await _client.get(_u('bootstrap'), headers: _headers);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw ApiError(body['error']?.toString() ?? 'Failed', res.statusCode);
    return body;
  }

  /// Authenticated GET on /app/v1/<path>.
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) async {
    final uri = _u(path).replace(queryParameters: query);
    final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  /// Authenticated POST on /app/v1/<path>.
  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) async {
    final res = await _client
        .post(_u(path), headers: _headers, body: jsonEncode(body ?? {}))
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiError('Unexpected reply from the server (${res.statusCode})', res.statusCode);
    }
    if (res.statusCode == 401) throw ApiError('Session expired. Please sign in again.', 401);
    if (res.statusCode >= 400 || body['success'] == false) {
      throw ApiError(body['error']?.toString() ?? 'Request failed', res.statusCode);
    }
    return body;
  }

  Future<void> registerDevice(Map<String, dynamic> device) async {
    await _client.post(_u('devices/register'), headers: _headers, body: jsonEncode(device));
  }
}

class ApiError implements Exception {
  ApiError(this.message, this.status);
  final String message;
  final int status;
  @override
  String toString() => message;
}
