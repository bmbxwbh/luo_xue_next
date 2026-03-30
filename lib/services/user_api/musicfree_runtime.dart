/// MusicFree 插件运行时 — 执行 MF 格式插件并封装接口调用
///
/// 用途：加载 MusicFree 格式的 JS 插件，调用其 search/getMediaSource/getLyric 等方法。
/// 参考：MusicFree/src/core/pluginManager/plugin.ts 的 PluginMethodsWrapper 类
///
/// 关键逻辑：
/// - 通过 QuickJS 执行插件代码（用 musicfree_preload.dart 提供的 executeMfPlugin）
/// - HTTP 请求通过事件队列传递到 Dart 侧（复用现有 __lx_event_queue__ 机制）
/// - MF 插件的 Promise 通过 Dart 侧轮询驱动解析
/// - 错误处理和超时
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';
import 'musicfree_preload.dart';
import 'plugin_format_detector.dart';

/// MusicFree 插件实例
class MusicFreePlugin {
  final String name;
  final String hash;
  final String path;
  final MfPluginMeta meta;

  const MusicFreePlugin({
    required this.name,
    required this.hash,
    required this.path,
    required this.meta,
  });

  bool get supportsSearch => meta.supportsSearch;
  bool get supportsGetMediaSource => meta.supportsGetMediaSource;
  bool get supportsGetLyric => meta.supportsGetLyric;

  Map<String, dynamic> toJson() => {
        'name': name,
        'hash': hash,
        'path': path,
        'meta': meta.toJson(),
      };

  factory MusicFreePlugin.fromJson(Map<String, dynamic> json) {
    return MusicFreePlugin(
      name: json['name'] as String? ?? '',
      hash: json['hash'] as String? ?? '',
      path: json['path'] as String? ?? '',
      meta: MfPluginMeta(
        platform: json['meta']?['platform'] as String? ?? json['name'] as String? ?? '',
        methods: ((json['meta']?['methods'] as List?) ?? [])
            .map((m) => MfPluginMethod.values.firstWhere(
                  (e) => e.name == m,
                  orElse: () => MfPluginMethod.search,
                ))
            .toList(),
      ),
    );
  }
}

/// MusicFree 运行时 — 管理 MF 插件的加载和调用
class MusicFreeRuntime {
  JavascriptRuntime? _jsRuntime;
  MusicFreePlugin? _currentPlugin;
  bool _initialized = false;
  Timer? _pollTimer;

  /// 脚本内容（用于每次调用时重新执行）
  String _pluginScript = '';

  /// 等待中的 Promise 回调
  final Map<String, Completer<dynamic>> _pendingPromises = {};

  /// 自增 Promise ID
  int _promiseIdCounter = 0;

  MusicFreePlugin? get currentPlugin => _currentPlugin;
  bool get isInitialized => _initialized && _currentPlugin != null;

  /// 初始化运行时，加载插件
  Future<bool> init(String scriptContent, String pluginPath) async {
    try {
      _pluginScript = scriptContent;

      // 转义脚本（用于嵌入到单引号字符串中）
      final escaped = _escapeForJs(scriptContent);

      // 创建 QuickJS 运行时
      _jsRuntime = getJavascriptRuntime();

      // 初始化事件队列
      _eval('globalThis.__lx_event_queue__ = [];');
      _eval('globalThis.__mf_result_store__ = {};');

      // 注入 MF 预加载脚本
      _eval(kMusicFreePreloadScript);

      // 执行插件并提取元信息
      final evalCode = '''
        (function() {
          var env = { appVersion: '1.0.0', os: 'android', lang: 'zh-CN', getUserVariables: function() { return {}; }, get userVariables() { return {}; } };
          var result = executeMfPlugin('$escaped', env);
          if (!result.success) return JSON.stringify({ error: result.error });
          var p = result.instance;
          return JSON.stringify({
            platform: p.platform || '',
            version: p.version || '',
            srcUrl: p.srcUrl || '',
            supportedSearchType: p.supportedSearchType || [],
            hasSearch: typeof p.search === 'function',
            hasGetMediaSource: typeof p.getMediaSource === 'function',
            hasGetLyric: typeof p.getLyric === 'function',
            hasGetMusicInfo: typeof p.getMusicInfo === 'function',
            hasGetAlbumInfo: typeof p.getAlbumInfo === 'function',
            hasImportMusicSheet: typeof p.importMusicSheet === 'function',
            hasImportMusicItem: typeof p.importMusicItem === 'function',
            hasGetTopLists: typeof p.getTopLists === 'function',
          });
        })()
      ''';

      final result = _eval(evalCode);
      final data = jsonDecode(result) as Map<String, dynamic>;

      if (data.containsKey('error')) {
        debugPrint('[MF] 插件解析错误: ${data['error']}');
        return false;
      }

      final methods = <MfPluginMethod>[];
      if (data['hasSearch'] == true) methods.add(MfPluginMethod.search);
      if (data['hasGetMediaSource'] == true) methods.add(MfPluginMethod.getMediaSource);
      if (data['hasGetLyric'] == true) methods.add(MfPluginMethod.getLyric);
      if (data['hasGetMusicInfo'] == true) methods.add(MfPluginMethod.getMusicInfo);
      if (data['hasGetAlbumInfo'] == true) methods.add(MfPluginMethod.getAlbumInfo);
      if (data['hasImportMusicSheet'] == true) methods.add(MfPluginMethod.importMusicSheet);
      if (data['hasImportMusicItem'] == true) methods.add(MfPluginMethod.importMusicItem);
      if (data['hasGetTopLists'] == true) methods.add(MfPluginMethod.getTopLists);

      final meta = MfPluginMeta(
        platform: data['platform'] as String? ?? '',
        version: data['version'] as String?,
        srcUrl: data['srcUrl'] as String?,
        methods: methods,
      );

      _currentPlugin = MusicFreePlugin(
        name: meta.platform,
        hash: '',
        path: pluginPath,
        meta: meta,
      );

      _initialized = true;
      debugPrint('[MF] 插件加载成功: ${meta.platform}, 方法: ${methods.map((m) => m.name).toList()}');
      return true;
    } catch (e) {
      debugPrint('[MF] 插件初始化异常: $e');
      return false;
    }
  }

  /// 调用插件方法（通用）
  ///
  /// [methodName] 方法名（如 'search'、'getMediaSource'、'getLyric'）
  /// [args] 参数列表（会被 JSON.stringify）
  /// [timeout] 超时时间
  /// 返回方法执行结果
  Future<dynamic> _callPluginMethod(
    String methodName,
    List<dynamic> args, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (!isInitialized) return null;

    final escaped = _escapeForJs(_pluginScript);
    final argsJson = jsonEncode(args);

    // 1. 调用插件方法，返回 Promise
    final promiseId = 'mf_promise_${++_promiseIdCounter}';
    final callCode = '''
      (function() {
        var env = { appVersion: '1.0.0', os: 'android', lang: 'zh-CN', getUserVariables: function() { return {}; }, get userVariables() { return {}; } };
        var result = executeMfPlugin('$escaped', env);
        if (!result.success) {
          globalThis.__mf_result_store__['$promiseId'] = JSON.stringify({error: result.error});
          return 'done';
        }
        var plugin = result.instance;
        var method = plugin['$methodName'];
        if (typeof method !== 'function') {
          globalThis.__mf_result_store__['$promiseId'] = JSON.stringify({error: 'method $methodName not found'});
          return 'done';
        }
        var args = JSON.parse('${argsJson.replaceAll("'", "\\'")}');
        try {
          var promise = method.apply(plugin, args);
          if (promise && typeof promise.then === 'function') {
            promise.then(function(r) {
              globalThis.__mf_result_store__['$promiseId'] = JSON.stringify(r);
            }).catch(function(e) {
              globalThis.__mf_result_store__['$promiseId'] = JSON.stringify({error: e.message || String(e)});
            });
            return 'pending';
          } else {
            globalThis.__mf_result_store__['$promiseId'] = JSON.stringify(promise);
            return 'done';
          }
        } catch(e) {
          globalThis.__mf_result_store__['$promiseId'] = JSON.stringify({error: e.message || String(e)});
          return 'done';
        }
      })()
    ''';

    final callResult = _eval(callCode);

    // 2. 如果同步完成，直接返回
    if (callResult == 'done') {
      return _consumeResult(promiseId);
    }

    // 3. 如果是 Promise，轮询等待
    final completer = Completer<dynamic>();
    _pendingPromises[promiseId] = completer;

    // 启动轮询（如果还没启动）
    _startPolling();

    // 等待结果或超时
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pendingPromises.remove(promiseId);
      debugPrint('[MF] $methodName 调用超时');
      return null;
    }
  }

  /// 消费已存储的结果
  dynamic _consumeResult(String promiseId) {
    final getResultCode = '''
      (function() {
        var r = globalThis.__mf_result_store__['$promiseId'];
        delete globalThis.__mf_result_store__['$promiseId'];
        return r || 'null';
      })()
    ''';
    final raw = _eval(getResultCode);
    if (raw == 'null' || raw.isEmpty) return null;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map && parsed.containsKey('error')) {
        debugPrint('[MF] 方法返回错误: ${parsed['error']}');
        return null;
      }
      return parsed;
    } catch (_) {
      return raw;
    }
  }

  /// 启动轮询（检查 Promise 结果 + 处理 HTTP 事件）
  void _startPolling() {
    if (_pollTimer != null && _pollTimer!.isActive) return;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 30), (_) => _poll());
  }

  /// 轮询处理
  void _poll() {
    if (_jsRuntime == null) {
      _pollTimer?.cancel();
      return;
    }

    // 1. 检查 Promise 结果
    if (_pendingPromises.isNotEmpty) {
      final checkCode = '''
        (function() {
          var results = {};
          var keys = Object.keys(globalThis.__mf_result_store__ || {});
          for (var i = 0; i < keys.length; i++) {
            var k = keys[i];
            if (k.indexOf('mf_promise_') === 0 && globalThis.__mf_result_store__[k]) {
              results[k] = globalThis.__mf_result_store__[k];
              delete globalThis.__mf_result_store__[k];
            }
          }
          return JSON.stringify(results);
        })()
      ''';
      try {
        final raw = _eval(checkCode);
        if (raw.isNotEmpty && raw != '{}') {
          final results = jsonDecode(raw) as Map<String, dynamic>;
          for (final entry in results.entries) {
            final completer = _pendingPromises.remove(entry.key);
            if (completer != null && !completer.isCompleted) {
              try {
                final value = jsonDecode(entry.value as String);
                if (value is Map && value.containsKey('error')) {
                  completer.complete(null);
                } else {
                  completer.complete(value);
                }
              } catch (_) {
                completer.complete(entry.value);
              }
            }
          }
        }
      } catch (_) {}
    }

    // 2. 处理 HTTP 事件（复用 __lx_event_queue__）
    try {
      final eventsCode = '''
        (function(){
          if(!globalThis.__lx_event_queue__||!globalThis.__lx_event_queue__.length) return '[]';
          var e=globalThis.__lx_event_queue__.splice(0);
          return JSON.stringify(e);
        })()
      ''';
      final eventsRaw = _eval(eventsCode);
      if (eventsRaw.isNotEmpty && eventsRaw != '[]') {
        final events = jsonDecode(eventsRaw) as List;
        for (final event in events) {
          final action = event['action'] as String?;
          final dataStr = event['data'] as String?;
          if (action == null || dataStr == null) continue;
          final data = jsonDecode(dataStr) as Map<String, dynamic>;

          if (action == 'mf_request') {
            _handleHttpRequest(data);
          } else if (action == '__log__') {
            debugPrint('[MF Plugin] ${data['msg']}');
          }
        }
      }
    } catch (_) {}

    // 3. 如果没有待处理的 Promise，停止轮询
    if (_pendingPromises.isEmpty) {
      _pollTimer?.cancel();
    }
  }

  /// 处理 HTTP 请求事件
  Future<void> _handleHttpRequest(Map<String, dynamic> data) async {
    final requestKey = data['requestKey'] as String?;
    final options = data['options'] as Map<String, dynamic>?;
    if (requestKey == null || options == null) return;

    final url = options['url'] as String? ?? '';
    final method = (options['method'] as String? ?? 'GET').toUpperCase();
    final headers = (options['headers'] as Map<String, dynamic>?)?.cast<String, String>() ?? {};
    final body = options['body'];
    final timeout = options['timeout'] as int? ?? 15000;

    try {
      // 使用 Dart 的 http 包发请求
      final client = _createHttpClient();
      final uri = Uri.parse(url);
      late dynamic response;

      if (method == 'GET') {
        response = await client.getUrl(uri).then((req) {
          headers.forEach((k, v) => req.headers.set(k, v));
          return req.close();
        }).timeout(Duration(milliseconds: timeout));
      } else if (method == 'POST') {
        response = await client.postUrl(uri).then((req) {
          headers.forEach((k, v) => req.headers.set(k, v));
          if (body != null) {
            req.write(body is String ? body : jsonEncode(body));
          }
          return req.close();
        }).timeout(Duration(milliseconds: timeout));
      } else {
        response = await client.getUrl(uri).then((req) {
          headers.forEach((k, v) => req.headers.set(k, v));
          return req.close();
        }).timeout(Duration(milliseconds: timeout));
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final statusCode = response.statusCode;

      // 注入响应到 JS
      final respJson = jsonEncode({
        'requestKey': requestKey,
        'error': null,
        'response': {
          'statusCode': statusCode,
          'statusMessage': '',
          'headers': {},
          'body': responseBody,
        }
      });
      final escapedResp = respJson.replaceAll("'", "\\'");
      _eval("handleMfNativeResponse(JSON.parse('$escapedResp'));");

      client.close();
    } catch (e) {
      final errJson = jsonEncode({
        'requestKey': requestKey,
        'error': e.toString(),
        'response': null,
      });
      final escapedErr = errJson.replaceAll("'", "\\'");
      _eval("handleMfNativeResponse(JSON.parse('$escapedErr'));");
    }
  }

  /// 调用插件的 search 方法
  Future<List<Map<String, dynamic>>> search(
    String query, int page, String type,
  ) async {
    final result = await _callPluginMethod('search', [query, page, type]);
    if (result is Map) {
      return ((result['data'] as List?) ?? []).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// 调用插件的 getMediaSource 方法
  Future<Map<String, dynamic>?> getMediaSource(
    Map<String, dynamic> musicItem, String quality,
  ) async {
    final result = await _callPluginMethod('getMediaSource', [musicItem, quality]);
    if (result is Map) {
      final url = result['url'] as String?;
      if (url != null && url.isNotEmpty) {
        return {
          'url': url,
          if (result['headers'] != null) 'headers': result['headers'],
          if (result['userAgent'] != null) 'userAgent': result['userAgent'],
        };
      }
    }
    return null;
  }

  /// 调用插件的 getLyric 方法
  Future<Map<String, dynamic>?> getLyric(Map<String, dynamic> musicItem) async {
    final result = await _callPluginMethod('getLyric', [musicItem]);
    if (result is Map) return result.cast<String, dynamic>();
    return null;
  }

  /// 创建 HTTP 客户端
  dynamic _createHttpClient() {
    // 使用 dart:io 的 HttpClient
    return _HttpClient();
  }

  /// eval 包装
  String _eval(String code) {
    try {
      final result = _jsRuntime!.evaluate(code);
      return result.stringResult;
    } catch (e) {
      debugPrint('[MF] eval 错误: $e');
      return '';
    }
  }

  /// 转义 JS 字符串（用于嵌入到单引号中）
  String _escapeForJs(String code) {
    return code
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');
  }

  /// 释放资源
  void dispose() {
    _pollTimer?.cancel();
    _jsRuntime?.dispose();
    _jsRuntime = null;
    _currentPlugin = null;
    _initialized = false;
    _pendingPromises.clear();
  }
}

// HTTP 客户端辅助类
class _HttpClient {
  final io.HttpClient _client = io.HttpClient();

  Future<_HttpRequest> getUrl(Uri uri) async {
    final req = await _client.getUrl(uri);
    return _HttpRequest(req);
  }

  Future<_HttpRequest> postUrl(Uri uri) async {
    final req = await _client.postUrl(uri);
    return _HttpRequest(req);
  }

  void close() => _client.close();
}

class _HttpRequest {
  final io.HttpClientRequest _req;
  _HttpRequest(this._req);

  _HttpRequest headers(Map<String, String> headers) {
    headers.forEach((k, v) => _req.headers.set(k, v));
    return this;
  }

  void write(dynamic body) {
    if (body is String) _req.write(body);
  }

  Future<_HttpResponse> close() async {
    final resp = await _req.close();
    return _HttpResponse(resp);
  }
}

class _HttpResponse {
  final io.HttpClientResponse _resp;
  _HttpResponse(this._resp);

  int get statusCode => _resp.statusCode;
  Future<String> transform(dynamic decoder) async {
    return await _resp.transform(utf8.decoder).join();
  }
}
