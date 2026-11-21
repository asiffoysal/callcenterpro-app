import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thin REST client for the /app/v1 API.
/// baseUrl is your server, e.g. https://cc.aitoyes.com
class ApiClient {
  ApiClient(this.baseUrl, {this.token});
  final String baseUrl;
  String? token;

  Uri _u(String path) => Uri.parse('$baseUrl/app/v1/$path');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> login({
    required String company,
    required String extension,
    required String password,
    Map<String, dynamic>? device,
  }) async {
    final res = await http.post(_u('login'),
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
    final res = await http.get(_u('bootstrap'), headers: _headers);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw ApiError(body['error']?.toString() ?? 'Failed', res.statusCode);
    return body;
  }

  Future<void> registerDevice(Map<String, dynamic> device) async {
    await http.post(_u('devices/register'), headers: _headers, body: jsonEncode(device));
  }
}

class ApiError implements Exception {
  ApiError(this.message, this.status);
  final String message;
  final int status;
  @override
  String toString() => message;
}
