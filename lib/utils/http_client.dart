import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_logger.dart';

class HttpResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;
  final dynamic jsonBody;
  final String? statusText;

  const HttpResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
    this.jsonBody,
    this.statusText,
  });

  bool get ok => statusCode >= 200 && statusCode < 300;
}

class HttpClient {
  static const _ua = 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36';

  static Future<HttpResponse> get(String url, {Map<String, String>? headers, Duration? timeout}) async {
    final merged = {'User-Agent': _ua, 'Accept': 'application/json', ...?headers};
    try {
      final resp = await http.get(Uri.parse(url), headers: merged).timeout(timeout ?? const Duration(seconds: 15));
      final result = _parse(resp);
      if (!result.ok) logger.warn('HTTP', 'GET $url → ${result.statusCode}');
      return result;
    } catch (e, st) {
      logger.error('HTTP', 'GET $url 失败: $e', st: st);
      rethrow;
    }
  }

  static Future<HttpResponse> post(String url, {Map<String, String>? headers, dynamic body, Duration? timeout}) async {
    final merged = {'User-Agent': _ua, 'Accept': 'application/json', 'Content-Type': 'application/json', ...?headers};
    try {
      final resp = await http.post(Uri.parse(url), headers: merged, body: body is String ? body : jsonEncode(body)).timeout(timeout ?? const Duration(seconds: 15));
      final result = _parse(resp);
      if (!result.ok) logger.warn('HTTP', 'POST $url → ${result.statusCode}');
      return result;
    } catch (e, st) {
      logger.error('HTTP', 'POST $url 失败: $e', st: st);
      rethrow;
    }
  }

  static Future<HttpResponse> postForm(String url, {Map<String, String>? headers, Map<String, String>? body, Duration? timeout}) async {
    final merged = {'User-Agent': _ua, 'Content-Type': 'application/x-www-form-urlencoded', ...?headers};
    try {
      final resp = await http.post(Uri.parse(url), headers: merged, body: body).timeout(timeout ?? const Duration(seconds: 15));
      return _parse(resp);
    } catch (e, st) {
      logger.error('HTTP', 'POST_FORM $url 失败: $e', st: st);
      rethrow;
    }
  }

  static HttpResponse _parse(http.Response resp) {
    // 有些服务器返回不规范的 Content-Type（如末尾多一个分号），手动处理
    String body;
    try {
      body = resp.body;
    } catch (_) {
      // resp.body 解析 Content-Type 失败时，直接用 bytes 转字符串
      body = utf8.decode(resp.bodyBytes);
    }
    dynamic jsonBody;
    try { jsonBody = jsonDecode(body); } catch (_) {}
    return HttpResponse(statusCode: resp.statusCode, body: body, headers: resp.headers, jsonBody: jsonBody, statusText: resp.reasonPhrase);
  }
}
