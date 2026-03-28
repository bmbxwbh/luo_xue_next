/// 用户 API 运行时 — 简化版，工具函数在 JS 端，Dart 只处理事件
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';
import '../../utils/http_client.dart';
import '../../utils/app_logger.dart';
import 'user_api_info.dart';
import 'user_api_preload.dart';

class UserApiRuntime {
  JavascriptRuntime? _jsRuntime;
  bool _initialized = false;
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};
  int _requestCounter = 0;
  final Completer<bool> _initCompleter = Completer<bool>();
  UserApiInfo? _apiInfo;
  Timer? _pollTimer;

  bool get isInitialized => _initialized;
  UserApiInfo? get apiInfo => _apiInfo;

  /// 统一日志：同时输出到 debugPrint 和 AppLogger
  void _log(String msg, {bool isError = false}) {
    debugPrint('[UserApiRuntime] $msg');
    if (isError) {
      logger.error('UserApiRuntime', msg);
    } else {
      logger.debug('UserApiRuntime', msg);
    }
  }

  /// 同步执行 JS 代码，返回结果字符串
  String _eval(String code) {
    final r = _jsRuntime!.evaluate(code);
    if (r.isError) _log('JS Error: ${r.stringResult}', isError: true);
    return r.stringResult;
  }

  Future<bool> init(UserApiInfo info, String script) async {
    try {
      _apiInfo = info;
      _jsRuntime = getJavascriptRuntime();

      // 1. 初始化事件队列
      _eval('globalThis.__lx_event_queue__ = [];');

      // 2. 加载预加载脚本
      _jsRuntime!.evaluate(kUserApiPreloadScript);

      // 3. 加载用户脚本
      _log('加载用户脚本... (${script.length} 字符)');
      final evalResult = _jsRuntime!.evaluate(script);
      if (evalResult.isError) {
        _log('⚠️ 用户脚本执行出错: ${evalResult.stringResult}', isError: true);
      } else {
        _log('脚本加载成功');
      }

      // 检查 handler 是否注册
      final handlerCheck = _eval('typeof __lx_handlers__["request"]');
      _log('request handler 类型: $handlerCheck');

      // 4. 调用 lx_setup
      _eval('''
        lx_setup('${info.id}','${info.id}','${info.name.replaceAll("'","\\'")}','${info.description.replaceAll("'","\\'")}','${info.version}','${info.author.replaceAll("'","\\'")}','${info.homepage}','');
      ''');

      // 5. 启动轮询
      _pollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) => _poll());

      // 6. 等待用户脚本调用 lx.send('inited')，超时 15 秒
      final result = await _initCompleter.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _log('⏰ 超时 - 检查 handler');
          return false;
        },
      );

      // 如果初始化失败但 handler 已注册，手动标记可用
      if (!result) {
        final handlerType = _eval('typeof __lx_handlers__["request"]');
        _log('handler 类型: $handlerType');
        if (handlerType == 'function') {
          _log('handler 已注册但未收到 inited，手动启用');
          _initialized = true;
          return true;
        }
      }

      _initialized = result;
      if (result) _log('✅ ${_apiInfo?.sources?.keys.toList()}');
      return result;
    } catch (e, s) {
      _log('❌ $e\n$s', isError: true);
      if (!_initCompleter.isCompleted) _initCompleter.complete(false);
      return false;
    }
  }

  void _poll() {
    if (_jsRuntime == null) return;
    try {
      final r = _eval('''
        (function(){if(!globalThis.__lx_event_queue__||!globalThis.__lx_event_queue__.length)return'[]';var e=globalThis.__lx_event_queue__.splice(0);return JSON.stringify(e);})()
      ''');
      if (r == '[]' || r.isEmpty) return;
      final events = jsonDecode(r);
      for (final e in events) {
        final action = e['action'] as String;
        final data = e['data'] != null ? jsonDecode(e['data']) : <String, dynamic>{};
        _handle(action, data);
      }
    } catch (e) {
      _log('Poll 错误: $e', isError: true);
    }
  }

  void _handle(String action, Map<String, dynamic> data) {
    switch (action) {
      case 'init':
        final status = data['status'] as bool? ?? false;
        final info = data['info'] as Map<String, dynamic>?;
        if (status && info != null) {
          final sources = <String, UserApiSourceInfo>{};
          final qList = <String, List<String>>{};
          if (info['sources'] is Map) {
            for (final e in (info['sources'] as Map).entries) {
              final src = e.key as String;
              final d = e.value as Map<String, dynamic>;
              final acts = <UserApiSourceAction>[];
              for (final a in (d['actions'] as List? ?? [])) {
                if (a == 'musicUrl') acts.add(UserApiSourceAction.musicUrl);
                if (a == 'lyric') acts.add(UserApiSourceAction.lyric);
                if (a == 'pic') acts.add(UserApiSourceAction.pic);
              }
              final qs = (d['qualitys'] as List? ?? []).cast<String>();
              sources[src] = UserApiSourceInfo(name: src, actions: acts, qualitys: qs);
              qList[src] = qs;
            }
          }
          if (_apiInfo != null) _apiInfo = _apiInfo!.copyWith(sources: sources);
          if (!_initCompleter.isCompleted) _initCompleter.complete(true);
        } else {
          _log('init fail: ${data['errorMessage']}', isError: true);
          if (!_initCompleter.isCompleted) _initCompleter.complete(false);
        }
        break;
      case 'request':
        final reqUrl = data['url'] as String? ?? 'unknown';
        _log('🌐 脚本请求: $reqUrl');
        _handleHttp(data);
      case 'response':
        final key = data['requestKey'] as String?;
        _log('Response: key=$key status=${data['status']}');
        if (key != null && _pendingRequests.containsKey(key)) {
          _pendingRequests[key]!.complete(data);
          _pendingRequests.remove(key);
        }
        break;
      case '__setTimeout__':
        final id = data['id'];
        final ms = data['ms'] as int? ?? 10;
        Future.delayed(Duration(milliseconds: ms), () {
          if (_jsRuntime != null) _eval("globalThis.__lx_fireTimeout__('$id');");
        });
        break;
      case '__log__':
        _log('[JS] ${data['msg']}');
        break;
    }
  }

  Future<void> _handleHttp(Map<String, dynamic> data) async {
    final key = data['requestKey'] as String;
    final url = data['url'] as String;
    final opts = data['options'] as Map<String, dynamic>? ?? {};
    final method = (opts['method'] as String? ?? 'GET').toUpperCase();
    final headers = (opts['headers'] as Map?)?.cast<String, String>() ?? {};
    final body = opts['body'];
    final jsTimeout = (opts['timeout'] as int?) ?? 30000;
    final timeoutDuration = Duration(milliseconds: jsTimeout > 15000 ? jsTimeout : 15000);
    _log('HTTP $method $url (key=$key, timeout=${timeoutDuration.inSeconds}s)');
    try {
      final httpFuture = method == 'POST'
          ? HttpClient.post(url, body: body is String ? body : (body != null ? jsonEncode(body) : null), headers: headers)
          : HttpClient.get(url, headers: headers);
      final resp = await httpFuture.timeout(timeoutDuration);
      _log('HTTP 响应: ${resp.statusCode} (${resp.body.length} 字节)');
      dynamic parsedBody;
      try {
        parsedBody = jsonDecode(resp.body);
      } catch (_) {
        parsedBody = resp.body;
      }
      final respData = {'statusCode': resp.statusCode, 'headers': resp.headers, 'body': parsedBody};
      final Map<String, dynamic> payload;
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        payload = {'error': 'HTTP ${resp.statusCode}', 'response': respData};
        _log('⚠️ HTTP 错误 ${resp.statusCode}', isError: true);
      } else {
        payload = {'error': null, 'response': respData};
      }
      final encoded = base64Encode(utf8.encode(jsonEncode(payload)));
      _eval("globalThis.__lx_setHttpResponse__('$key','$encoded');");
    } catch (e) {
      _log('HTTP 错误 (key=$key): $e', isError: true);
      try {
        final encoded = base64Encode(utf8.encode(jsonEncode({'error': e.toString(), 'response': null})));
        _eval("globalThis.__lx_setHttpResponse__('$key','$encoded');");
      } catch (e2) {
        _log('❌ 传递 HTTP 错误给 JS 失败: $e2', isError: true);
      }
    }
  }

  Future<Map<String, dynamic>> _callHandler(String source, String action, Map<String, dynamic> info) async {
    if (_jsRuntime == null) throw Exception('未初始化');
    final key = 'req_${++_requestCounter}';
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[key] = completer;
    _log('调用 handler: source=$source action=$action key=$key');

    // 直接传 JS 对象字面量，不用 JSON.parse
    final infoLiteral = _toJs(info);
    _log('infoLiteral 前300字符: ${infoLiteral.length > 300 ? infoLiteral.substring(0, 300) : infoLiteral}');
    _eval('globalThis.__lx_call_info__=$infoLiteral;');
    final jsCode = '''
        (function(){try{
          var handler=__lx_handlers__['request'];
          if(!handler){__pushEvent__('response',{requestKey:'$key',status:false,errorMessage:'Request event is not defined'});return;}
          handler.call(globalThis.lx, {source:'$source',action:'$action',info:globalThis.__lx_call_info__}).then(function(response){
            console.log('handler response: '+JSON.stringify(response));
            var result;
            switch('$action'){
              case 'musicUrl':
                var url=__verifyUrl__(response);
                result={source:'$source',action:'$action',data:{type:globalThis.__lx_call_info__.type,url:url}};
                break;
              case 'lyric':
                result={source:'$source',action:'$action',data:__verifyLyric__(response)};
                break;
              case 'pic':
                var picUrl=__verifyUrl__(response);
                result={source:'$source',action:'$action',data:picUrl};
                break;
              default:
                result={source:'$source',action:'$action',data:response};
            }
            __pushEvent__('response',{requestKey:'$key',status:true,result:result});
          }).catch(function(err){
            console.log('handler error: '+err.message);
            __pushEvent__('response',{requestKey:'$key',status:false,errorMessage:err.message||String(err)});
          });
        }catch(err){__pushEvent__('response',{requestKey:'$key',status:false,errorMessage:err.message||String(err)});}})()
      ''';
    try {
      _log('evaluate jsCode 长度: ${jsCode.length}');
      _log('jsCode 前500字符: ${jsCode.length > 500 ? jsCode.substring(0, 500) : jsCode}');
      final result = _jsRuntime!.evaluate(jsCode);
      if (result.isError) {
        _log('⚠️ JS evaluate 错误: ${result.stringResult}', isError: true);
        if (!completer.isCompleted) {
          completer.complete({'status': false, 'errorMessage': 'JS error: ${result.stringResult}'});
        }
      }
    } catch (e) {
      _log('evaluate 出错: $e', isError: true);
      if (!completer.isCompleted) {
        completer.complete({'status': false, 'errorMessage': 'evaluate error: $e'});
      }
    }

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () { _pendingRequests.remove(key); throw Exception('超时'); },
    );
  }

  Future<String> getMusicUrl({required String source, required Map<String, dynamic> musicInfo, required String quality}) async {
    // 传嵌套 info 给 handler，但 __lx_info_str__ 存平铺 musicInfo（标准格式）
    final r = await _callHandler(source, 'musicUrl', {'type': quality, 'musicInfo': musicInfo});
    if (r['status'] == true) return r['result']['data']['url'] as String;
    throw Exception(r['errorMessage'] ?? '失败');
  }

  Future<Map<String, dynamic>> getLyric({required String source, required Map<String, dynamic> musicInfo}) async {
    final r = await _callHandler(source, 'lyric', {'musicInfo': musicInfo});
    if (r['status'] == true) return r['result']['data'] as Map<String, dynamic>;
    return {};
  }

  Future<String> getPic({required String source, required Map<String, dynamic> musicInfo}) async {
    final r = await _callHandler(source, 'pic', {'musicInfo': musicInfo});
    if (r['status'] == true) return r['result']['data'] as String;
    return '';
  }

  /// Dart 值 → JS 字面量（单引号字符串、键名无引号）
  static String _toJs(dynamic v) {
    if (v == null) return 'null';
    if (v is bool) return v ? 'true' : 'false';
    if (v is int) return v.toString();
    if (v is double) {
      if (v.isNaN) return 'NaN';
      if (v.isInfinite) return v.isNegative ? '-Infinity' : 'Infinity';
      return v.toString();
    }
    if (v is String) {
      final buf = StringBuffer("'");
      for (final ch in v.runes) {
        if (ch == 0x5C) buf.write('\\\\');
        else if (ch == 0x27) buf.write("\\'");
        else if (ch == 0x0A) buf.write('\\n');
        else if (ch == 0x0D) buf.write('\\r');
        else if (ch == 0x09) buf.write('\\t');
        else if (ch < 0x20) buf.write('\\u${ch.toRadixString(16).padLeft(4, '0')}');
        else buf.writeCharCode(ch);
      }
      buf.write("'");
      return buf.toString();
    }
    if (v is List) {
      if (v.isEmpty) return '[]';
      return '[${v.map(_toJs).join(', ')}]';
    }
    if (v is Map) {
      if (v.isEmpty) return '{}';
      final buf = StringBuffer('{');
      var first = true;
      for (final e in v.entries) {
        if (!first) buf.write(', ');
        final k = e.key.toString();
        // 以数字开头的键名需要加引号（如 128k、320k）
        if (k.isNotEmpty && (k.codeUnitAt(0) >= 0x30 && k.codeUnitAt(0) <= 0x39)) {
          buf.write("'$k'");
        } else {
          buf.write(k);
        }
        buf.write(': ');
        buf.write(_toJs(e.value));
        first = false;
      }
      buf.write('}');
      return buf.toString();
    }
    return _toJs(v.toString());
  }

  void dispose() {
    _pollTimer?.cancel();
    _jsRuntime?.dispose();
    _jsRuntime = null;
    _initialized = false;
    _pendingRequests.clear();
  }
}
