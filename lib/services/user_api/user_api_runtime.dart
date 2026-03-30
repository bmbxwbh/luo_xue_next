/// 用户 API 运行时 — 对齐洛雪原版 QuickJS + native 桥接架构
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:http/http.dart' as http;
import '../../utils/app_logger.dart';
import 'user_api_info.dart';
import 'user_api_preload.dart';

/// 活跃 HTTP 请求信息（支持真实 abort）
class _ActiveRequest {
  final http.Client client;
  bool aborted = false;

  _ActiveRequest(this.client);
}

class UserApiRuntime {
  JavascriptRuntime? _jsRuntime;
  bool _initialized = false;
  int _requestCounter = 0;
  final Completer<bool> _initCompleter = Completer<bool>();
  UserApiInfo? _apiInfo;
  Timer? _pollTimer;

  /// 活跃 HTTP 请求 Map，用于支持真实 abort
  final Map<String, _ActiveRequest> _activeRequests = {};

  bool get isInitialized => _initialized;
  UserApiInfo? get apiInfo => _apiInfo;

  /// 统一日志
  void _log(String msg, {bool isError = false}) {
    debugPrint('[UserApiRuntime] $msg');
    if (isError) {
      logger.error('UserApiRuntime', msg);
    } else {
      logger.debug('UserApiRuntime', msg);
    }
  }

  /// 同步执行 JS
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

      // 2. 注入 abort 请求队列
      _eval('globalThis.__lx_abort_queue__ = [];');

      // 3. 加载预加载脚本
      _jsRuntime!.evaluate(kUserApiPreloadScript);

      // 4. 加载用户脚本
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

      // 5. 调用 lx_setup
      _eval('''
        lx_setup('${info.id}','${info.id}','${info.name.replaceAll("'", "\\'")}','${info.description.replaceAll("'", "\\'")}','${info.version}','${info.author.replaceAll("'", "\\'")}','${info.homepage}','');
      ''');

      // 6. 启动轮询
      _pollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) => _poll());

      // 7. 等待初始化，超时 15 秒
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

  // ==================== Abort 支持（修复 #1） ====================

  /// 检查并处理 abort 请求
  void _processAborts() {
    final r = _eval('''
      (function(){
        if(!globalThis.__lx_abort_queue__||!globalThis.__lx_abort_queue__.length)return '[]';
        var a=globalThis.__lx_abort_queue__.splice(0);
        return JSON.stringify(a);
      })()
    ''');
    if (r == '[]' || r.isEmpty) return;
    try {
      final keys = jsonDecode(r) as List;
      for (final key in keys) {
        final k = key as String;
        final req = _activeRequests[k];
        if (req != null) {
          req.aborted = true;
          req.client.close();
          _activeRequests.remove(k);
          _log('🚫 请求已取消: $k');
        }
      }
    } catch (e) {
      _log('处理 abort 出错: $e', isError: true);
    }
  }

  // ==================== 事件循环（修复 #5） ====================

  /// 轮询事件队列
  void _poll() {
    if (_jsRuntime == null) return;
    try {
      // 先处理 abort 请求
      _processAborts();

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

  // ==================== HTTP 处理（修复 #4、#5） ====================

  Future<void> _handleHttp(Map<String, dynamic> data) async {
    final key = data['requestKey'] as String;
    final url = data['url'] as String;
    final opts = data['options'] as Map<String, dynamic>? ?? {};
    final method = (opts['method'] as String? ?? 'GET').toUpperCase();
    final headers = <String, String>{
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36',
      'Accept': 'application/json',
      ...?(opts['headers'] as Map?)?.cast<String, String>(),
    };
    final body = opts['body'];
    final jsTimeout = (opts['timeout'] as int?) ?? 30000;
    final timeoutDuration = Duration(milliseconds: jsTimeout > 15000 ? jsTimeout : 15000);
    _log('HTTP $method $url (key=$key, timeout=${timeoutDuration.inSeconds}s)');

    // 修复 #1: 创建可取消的 HTTP 客户端
    final client = http.Client();
    final activeReq = _ActiveRequest(client);
    _activeRequests[key] = activeReq;

    try {
      late http.Response resp;
      final uri = Uri.parse(url);

      if (method == 'POST') {
        resp = await client.post(uri, headers: headers, body: body is String ? body : (body != null ? jsonEncode(body) : null)).timeout(timeoutDuration);
      } else {
        resp = await client.get(uri, headers: headers).timeout(timeoutDuration);
      }

      // 检查是否已 abort
      if (activeReq.aborted) {
        _eval("handleNativeResponse(${jsonEncode({'error': 'Request aborted', 'requestKey': key, 'response': null})});");
        return;
      }

      _log('HTTP 响应: ${resp.statusCode} (${resp.body.length} 字节)');

      // 解析 body
      dynamic parsedBody;
      try { parsedBody = jsonDecode(resp.body); } catch (_) { parsedBody = resp.body; }

      // 修复 #4: 只返回原版有的字段（statusCode, statusMessage, headers, body），去掉 url 和 ok
      final respData = {
        'statusCode': resp.statusCode,
        'statusMessage': resp.reasonPhrase ?? '',
        'headers': resp.headers,
        'body': parsedBody,
      };

      _eval("handleNativeResponse(${jsonEncode({
        'error': resp.statusCode >= 200 && resp.statusCode < 300 ? null : 'HTTP ${resp.statusCode}',
        'requestKey': key,
        'response': respData,
      })});");
    } catch (e) {
      if (!activeReq.aborted) {
        _log('HTTP 错误 (key=$key): $e', isError: true);
      }
      try {
        _eval("handleNativeResponse(${jsonEncode({
          'error': activeReq.aborted ? 'Request aborted' : e.toString(),
          'requestKey': key,
          'response': null,
        })});");
      } catch (e2) {
        _log('❌ 传递 HTTP 错误给 JS 失败: $e2', isError: true);
      }
    } finally {
      _activeRequests.remove(key);
      client.close();
    }
  }

  // ==================== Handler 调用 ====================

  Future<Map<String, dynamic>> _callHandler(String source, String action, Map<String, dynamic> info) async {
    if (_jsRuntime == null) throw Exception('未初始化');
    final key = 'req_${++_requestCounter}';

    _log('调用 handler: source=$source action=$action key=$key');

    final infoJson = jsonEncode(info);
    final jsCode = '''
      (function(info){try{
        var handler=__lx_handlers__['request'];
        if(!handler){__pushEvent__('response',{requestKey:'$key',status:false,errorMessage:'Request event is not defined'});return;}
        handler.call(globalThis.lx, {source:'$source',action:'$action',info:info}).then(function(response){
          var result;
          switch('$action'){
            case 'musicUrl':
              if(typeof response!=='string'||response.length>2048||!/^https?:/.test(response))throw new Error('failed');
              result={source:'$source',action:'$action',data:{type:info.type,url:response}};
              break;
            case 'lyric':
              if(typeof response!=='object'||typeof response.lyric!=='string')throw new Error('failed');
              if(response.lyric.length>51200)throw new Error('failed');
              result={source:'$source',action:'$action',data:{
                lyric:response.lyric,
                tlyric:(typeof response.tlyric==='string'&&response.tlyric.length<5120)?response.tlyric:null,
                rlyric:(typeof response.rlyric==='string'&&response.rlyric.length<5120)?response.rlyric:null,
                lxlyric:(typeof response.lxlyric==='string'&&response.lxlyric.length<8192)?response.lxlyric:null
              }};
              break;
            case 'pic':
              if(typeof response!=='string'||response.length>2048||!/^https?:/.test(response))throw new Error('failed');
              result={source:'$source',action:'$action',data:response};
              break;
            default:
              result={source:'$source',action:'$action',data:response};
          }
          __pushEvent__('response',{requestKey:'$key',status:true,result:result});
        }).catch(function(err){
          __pushEvent__('response',{requestKey:'$key',status:false,errorMessage:err.message||String(err)});
        });
      }catch(err){__pushEvent__('response',{requestKey:'$key',status:false,errorMessage:err.message||String(err)});}})($infoJson)
    ''';

    try {
      final result = _jsRuntime!.evaluate(jsCode);
      if (result.isError) {
        _log('⚠️ JS evaluate 错误: ${result.stringResult}', isError: true);
        return {'status': false, 'errorMessage': 'JS error: ${result.stringResult}'};
      }
    } catch (e) {
      _log('evaluate 出错: $e', isError: true);
      return {'status': false, 'errorMessage': 'evaluate error: $e'};
    }

    // 修复 #5: 等待响应到达（JS handler → HTTP 请求 → 注入响应 → response 事件）
    for (int i = 0; i < 600; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (_jsRuntime == null) break;
      try {
        // 先处理 abort
        _processAborts();

        final r = _eval('''
          (function(){if(!globalThis.__lx_event_queue__||!globalThis.__lx_event_queue__.length)return'[]';var e=globalThis.__lx_event_queue__.splice(0);return JSON.stringify(e);})()
        ''');
        if (r == '[]' || r.isEmpty) continue;
        final events = jsonDecode(r);
        for (final e in events) {
          final evtAction = e['action'] as String;
          final evtData = e['data'] != null ? jsonDecode(e['data']) : <String, dynamic>{};

          if (evtAction == 'response' && evtData['requestKey'] == key) {
            return evtData;
          }

          // 其他事件正常处理
          _handle(evtAction, evtData);
        }
      } catch (_) {}
    }

    return {'status': false, 'errorMessage': '超时'};
  }

  // ==================== 公开 API ====================

  Future<String> getMusicUrl({required String source, required Map<String, dynamic> musicInfo, required String quality}) async {
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

  void dispose() {
    _pollTimer?.cancel();
    // 取消所有活跃请求
    for (final req in _activeRequests.values) {
      req.aborted = true;
      req.client.close();
    }
    _activeRequests.clear();
    _jsRuntime?.dispose();
    _jsRuntime = null;
    _initialized = false;
  }
}
