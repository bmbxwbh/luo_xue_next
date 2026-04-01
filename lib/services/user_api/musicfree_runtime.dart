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
      final preloadResult = _eval(kMusicFreePreloadScript);
      if (preloadResult.isEmpty) {
        debugPrint('[MF] 预加载脚本执行失败，请检查脚本语法');
        return false;
      }

      // 验证关键函数是否存在
      final checkResult = _eval('typeof executeMfPlugin');
      if (checkResult != 'function') {
        debugPrint('[MF] executeMfPlugin 未定义，预加载脚本可能不完整');
        return false;
      }

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
            hasSearchMusic: typeof p.searchMusic === 'function',
            hasSearchAlbum: typeof p.searchAlbum === 'function',
            hasSearchMusicSheet: typeof p.searchMusicSheet === 'function',
            hasGetMediaSource: typeof p.getMediaSource === 'function',
            hasGetLyric: typeof p.getLyric === 'function',
            hasGetMusicInfo: typeof p.getMusicInfo === 'function',
            hasGetAlbumInfo: typeof p.getAlbumInfo === 'function',
            hasImportMusicSheet: typeof p.importMusicSheet === 'function',
            hasImportMusicItem: typeof p.importMusicItem === 'function',
            hasGetTopLists: typeof p.getTopLists === 'function',
            hasGetRecommendSheetTags: typeof p.getRecommendSheetTags === 'function',
            hasGetRecommendSheetsByTag: typeof p.getRecommendSheetsByTag === 'function',
            hasGetMusicSheetInfo: typeof p.getMusicSheetInfo === 'function',
            hasGetTopListDetail: typeof p.getTopListDetail === 'function',
            appVersion: p.appVersion || '',
            order: p.order || 0,
            cacheControl: p.cacheControl || '',
            primaryKey: p.primaryKey || [],
            hints: p.hints || {},
          });
        })()
      ''';

      final result = _eval(evalCode);
      if (result.isEmpty) {
        debugPrint('[MF] 插件执行返回空，可能脚本有语法错误');
        return false;
      }

      dynamic parsed;
      try {
        parsed = jsonDecode(result);
      } catch (e) {
        debugPrint('[MF] 插件解析 JSON 失败: $e, result=$result');
        return false;
      }
      if (parsed is! Map<String, dynamic>) {
        debugPrint('[MF] 插件解析结果不是对象: ${parsed.runtimeType}');
        return false;
      }
      final data = parsed;

      if (data.containsKey('error')) {
        debugPrint('[MF] 插件解析错误: ${data['error']}');
        return false;
      }

      final methods = <MfPluginMethod>[];
      if (data['hasSearch'] == true) methods.add(MfPluginMethod.search);
      if (data['hasSearchMusic'] == true) methods.add(MfPluginMethod.searchMusic);
      if (data['hasSearchAlbum'] == true) methods.add(MfPluginMethod.searchAlbum);
      if (data['hasSearchMusicSheet'] == true) methods.add(MfPluginMethod.searchMusicSheet);
      if (data['hasGetMediaSource'] == true) methods.add(MfPluginMethod.getMediaSource);
      if (data['hasGetLyric'] == true) methods.add(MfPluginMethod.getLyric);
      if (data['hasGetMusicInfo'] == true) methods.add(MfPluginMethod.getMusicInfo);
      if (data['hasGetAlbumInfo'] == true) methods.add(MfPluginMethod.getAlbumInfo);
      if (data['hasImportMusicSheet'] == true) methods.add(MfPluginMethod.importMusicSheet);
      if (data['hasImportMusicItem'] == true) methods.add(MfPluginMethod.importMusicItem);
      if (data['hasGetTopLists'] == true) methods.add(MfPluginMethod.getTopLists);
      if (data['hasGetRecommendSheetTags'] == true) methods.add(MfPluginMethod.getRecommendSheetTags);
      if (data['hasGetRecommendSheetsByTag'] == true) methods.add(MfPluginMethod.getRecommendSheetsByTag);
      if (data['hasGetMusicSheetInfo'] == true) methods.add(MfPluginMethod.getMusicSheetInfo);
      if (data['hasGetTopListDetail'] == true) methods.add(MfPluginMethod.getTopListDetail);

      final meta = MfPluginMeta(
        platform: data['platform'] as String? ?? '',
        version: data['version'] as String?,
        srcUrl: data['srcUrl'] as String?,
        appVersion: data['appVersion'] as String?,
        cacheControl: data['cacheControl'] as String?,
        order: data['order'] is int ? data['order'] : 0,
        primaryKey: (data['primaryKey'] as List?)?.cast<String>() ?? [],
        hints: (data['hints'] as Map?)?.cast<String, dynamic>() ?? {},
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
          } else if (action == 'mf_crypto') {
            _handleCryptoRequest(data);
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
      // 使用 dart:io HttpClient 发请求
      final client = io.HttpClient();
      final uri = Uri.parse(url);
      final timeoutDuration = Duration(milliseconds: timeout);

      late io.HttpClientRequest req;
      if (method == 'POST') {
        req = await client.postUrl(uri).timeout(timeoutDuration);
      } else if (method == 'PUT') {
        req = await client.putUrl(uri).timeout(timeoutDuration);
      } else {
        req = await client.getUrl(uri).timeout(timeoutDuration);
      }

      // 设置 headers
      headers.forEach((k, v) => req.headers.set(k, v));

      // 写入 body
      if (body != null && (method == 'POST' || method == 'PUT')) {
        final bodyStr = body is String ? body : jsonEncode(body);
        req.write(bodyStr);
      }

      final resp = await req.close().timeout(timeoutDuration);
      final statusCode = resp.statusCode;
      final responseBody = await resp.transform(utf8.decoder).join().timeout(timeoutDuration);

      // 收集响应 headers
      final respHeaders = <String, String>{};
      resp.headers.forEach((name, values) {
        respHeaders[name] = values.join(', ');
      });

      // 注入响应到 JS
      final respJson = jsonEncode({
        'requestKey': requestKey,
        'error': null,
        'response': {
          'statusCode': statusCode,
          'statusMessage': '',
          'headers': respHeaders,
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

  /// 处理 MF 插件的加密请求（SHA256/AES 异步回退）
  /// 注意：纯 JS SHA256/AES 已在 preload 中实现，此方法作为兜底
  Future<void> _handleCryptoRequest(Map<String, dynamic> data) async {
    final requestKey = data['requestKey'] as String?;
    if (requestKey == null) return;

    try {
      // 纯 JS 已处理，此分支不应触发，但保留以防万一
      final respJson = jsonEncode({
        'requestKey': requestKey,
        'error': null,
        'result': '',
      });
      final escapedResp = respJson.replaceAll("'", "\\'");
      _eval("handleMfCryptoResponse(JSON.parse('$escapedResp'));");
    } catch (e) {
      final errJson = jsonEncode({
        'requestKey': requestKey,
        'error': e.toString(),
        'result': null,
      });
      final escapedErr = errJson.replaceAll("'", "\\'");
      _eval("handleMfCryptoResponse(JSON.parse('$escapedErr'));");
    }
  }

  /// 调用插件的 search 方法
  /// MF 原版返回: { isEnd?: boolean, data: IMusicItem[] }
  /// Parcel 打包的插件可能用 searchMusic/searchAlbum/searchMusicSheet 替代
  Future<Map<String, dynamic>> search(
    String query, int page, String type,
  ) async {
    // 优先使用标准 search(query, page, type)
    dynamic result = await _callPluginMethod('search', [query, page, type]);

    // 标准 search 无效时，回退到类型特化方法（Parcel 打包格式）
    if (result == null) {
      String methodName;
      switch (type) {
        case 'music':
          methodName = 'searchMusic';
          break;
        case 'album':
          methodName = 'searchAlbum';
          break;
        case 'sheet':
          methodName = 'searchMusicSheet';
          break;
        default:
          methodName = 'searchMusic';
      }
      result = await _callPluginMethod(methodName, [query, page]);
    }

    if (result is Map) {
      return {
        'isEnd': result['isEnd'] ?? true,
        'data': ((result['data'] as List?) ?? []).cast<Map<String, dynamic>>(),
      };
    }
    return {'isEnd': true, 'data': <Map<String, dynamic>>[]};
  }

  /// 调用插件的 getMediaSource 方法
  /// 部分插件（如酷我念心、网易念心、网易 Ciallo、xiaowo）不提供 getMediaSource，
  /// 搜索结果自带 url 字段，此时直接从 musicItem 取 url
  Future<Map<String, dynamic>?> getMediaSource(
    Map<String, dynamic> musicItem, String quality,
  ) async {
    // 先尝试调用插件的 getMediaSource
    if (currentPlugin?.meta.methods.contains(MfPluginMethod.getMediaSource) == true) {
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
    }

    // getMediaSource 不可用或返回空时，回退到搜索结果中的 url 字段
    final url = musicItem['url'] as String?;
    if (url != null && url.isNotEmpty) {
      debugPrint('[MF] getMediaSource 回退到搜索结果 url: $url');
      return {'url': url};
    }

    return null;
  }

  /// 调用插件的 getLyric 方法
  /// 多数插件用 rawLrc，网易插件用 rawLrcTxt，统一处理
  Future<Map<String, dynamic>?> getLyric(Map<String, dynamic> musicItem) async {
    final result = await _callPluginMethod('getLyric', [musicItem]);
    if (result is Map) {
      final map = result.cast<String, dynamic>();
      // 统一歌词字段：rawLrcTxt → rawLrc
      if (map['rawLrc'] == null && map['rawLrcTxt'] != null) {
        map['rawLrc'] = map['rawLrcTxt'];
      }
      return map;
    }
    return null;
  }

  /// 调用插件的 getRecommendSheetTags 方法（获取歌单分类标签）
  Future<Map<String, dynamic>?> getRecommendSheetTags() async {
    final result = await _callPluginMethod('getRecommendSheetTags', []);
    if (result is Map) return result.cast<String, dynamic>();
    return null;
  }

  /// 调用插件的 getRecommendSheetsByTag 方法（获取分类下的歌单列表）
  Future<Map<String, dynamic>> getRecommendSheetsByTag(Map<String, dynamic> tag, int page) async {
    final result = await _callPluginMethod('getRecommendSheetsByTag', [tag, page]);
    if (result is Map) {
      return {
        'isEnd': result['isEnd'] ?? true,
        'data': ((result['data'] as List?) ?? []).cast<Map<String, dynamic>>(),
      };
    }
    return {'isEnd': true, 'data': <Map<String, dynamic>>[]};
  }

  /// 调用插件的 getMusicSheetInfo 方法（获取歌单详情）
  Future<Map<String, dynamic>?> getMusicSheetInfo(Map<String, dynamic> sheetItem, int page) async {
    final result = await _callPluginMethod('getMusicSheetInfo', [sheetItem, page]);
    if (result is Map) return result.cast<String, dynamic>();
    return null;
  }

  /// 调用插件的 importMusicSheet 方法（导入歌单）
  Future<List<Map<String, dynamic>>> importMusicSheet(String url) async {
    final result = await _callPluginMethod('importMusicSheet', [url]);
    if (result is List) return result.cast<Map<String, dynamic>>();
    return [];
  }

  /// 调用插件的 getTopLists 方法（获取榜单列表）
  Future<List<Map<String, dynamic>>> getTopLists() async {
    final result = await _callPluginMethod('getTopLists', []);
    if (result is List) return result.cast<Map<String, dynamic>>();
    if (result is Map && result['data'] is List) return (result['data'] as List).cast<Map<String, dynamic>>();
    return [];
  }

  /// 调用插件的 getTopListDetail 方法（获取榜单详情）
  Future<Map<String, dynamic>?> getTopListDetail(Map<String, dynamic> topListItem, int page) async {
    final result = await _callPluginMethod('getTopListDetail', [topListItem, page]);
    if (result is Map) return result.cast<String, dynamic>();
    return null;
  }

  /// eval 包装（统一错误处理）
  String _eval(String code) {
    try {
      final result = _jsRuntime!.evaluate(code);
      final str = result.stringResult;
      // 检测 JS 返回的错误（JS 异常不会抛 Dart 异常，而是返回错误字符串）
      if (str.startsWith('ReferenceError:') ||
          str.startsWith('TypeError:') ||
          str.startsWith('SyntaxError:') ||
          str.startsWith('Error:') ||
          str.startsWith('RangeError:') ||
          str.startsWith('URIError:') ||
          str.startsWith('EvalError:')) {
        debugPrint('[MF] JS 错误: ${str.substring(0, str.length > 200 ? 200 : str.length)}');
        return '';
      }
      return str;
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
