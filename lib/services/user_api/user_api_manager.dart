/// 用户 API 管理器 — 对齐 LX Music core/userApi.ts
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_api_info.dart';
import 'user_api_state.dart';
import 'user_api_runtime.dart';

/// 用户 API 管理器
class UserApiManager extends ChangeNotifier {
  static const _keyApiList = 'user_api_list';
  static const _keyApiPrefix = 'user_api_';

  final UserApiState _state = UserApiState();
  UserApiRuntime? _runtime;

  /// 状态
  UserApiState get state => _state;

  /// 是否已初始化
  bool get isInitialized => _state.status;

  /// 当前 API 的音源
  Map<String, UserApiSourceInfo> get apis => _state.apis;

  /// 音质列表
  Map<String, List<String>> get qualityList => _state.qualityList;

  /// 初始化
  Future<void> init() async {
    await _loadApiList();
    // 自动初始化第一个已导入的用户音源
    if (_state.list.isNotEmpty) {
      try {
        await setUserApi(_state.list.first.id);
      } catch (e) {
        debugPrint('[UserApiManager] 自动初始化失败: $e');
      }
    }
  }

  /// 加载 API 列表
  Future<void> _loadApiList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getString(_keyApiList);
      if (listJson == null) return;

      final list = jsonDecode(listJson) as List;
      final apis = list
          .map((e) => UserApiInfo.fromJson(e as Map<String, dynamic>))
          .toList();

      _state.setList(apis);
    } catch (e) {
      debugPrint('[UserApiManager] 加载 API 列表失败: $e');
    }
  }

  /// 保存 API 列表
  Future<void> _saveApiList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = jsonEncode(_state.list.map((e) => e.toJson()).toList());
      await prefs.setString(_keyApiList, listJson);
    } catch (e) {
      debugPrint('[UserApiManager] 保存 API 列表失败: $e');
    }
  }

  /// 保存 API 脚本
  Future<void> _saveApiScript(String id, String script) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_keyApiPrefix$id', script);
    } catch (e) {
      debugPrint('[UserApiManager] 保存 API 脚本失败: $e');
    }
  }

  /// 获取 API 脚本
  Future<String?> _getApiScript(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_keyApiPrefix$id');
    } catch (e) {
      debugPrint('[UserApiManager] 获取 API 脚本失败: $e');
      return null;
    }
  }

  /// 删除 API 脚本
  Future<void> _removeApiScript(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_keyApiPrefix$id');
    } catch (e) {
      debugPrint('[UserApiManager] 删除 API 脚本失败: $e');
    }
  }

  /// 导入用户 API
  Future<UserApiInfo> importUserApi(String script) async {
    // 解析脚本头部信息
    final info = _parseScriptInfo(script);

    // 生成 ID
    final id = 'user_api_${DateTime.now().millisecondsSinceEpoch}';

    // 创建 API 信息
    final apiInfo = UserApiInfo(
      id: id,
      name: info['name'] ?? '未命名',
      description: info['description'] ?? '',
      author: info['author'] ?? '',
      homepage: info['homepage'] ?? '',
      version: info['version'] ?? '',
    );

    // 保存
    _state.addUserApi(apiInfo);
    await _saveApiScript(id, script);
    await _saveApiList();

    return apiInfo;
  }

  /// 解析脚本头部信息
  Map<String, String> _parseScriptInfo(String script) {
    final info = <String, String>{};

    // 匹配 /** ... */ 注释块
    final match = RegExp(r'/\*[\S\s]+?\*/').firstMatch(script);
    if (match == null) return info;

    final comment = match.group(0)!;

    // 匹配 @key value
    final rxp = RegExp(r'^\s?\*\s?@(\w+)\s(.+)$', multiLine: true);
    for (final m in rxp.allMatches(comment)) {
      final key = m.group(1)!;
      final value = m.group(2)!.trim();

      // 限制长度
      const maxLen = {
        'name': 24,
        'description': 36,
        'author': 56,
        'homepage': 1024,
        'version': 36,
      };

      if (maxLen.containsKey(key)) {
        info[key] = value.length > maxLen[key]!
            ? '${value.substring(0, maxLen[key])}...'
            : value;
      }
    }

    return info;
  }

  /// 设置当前 API
  Future<void> setUserApi(String apiId) async {
    // 销毁旧的运行时
    _runtime?.dispose();
    _runtime = null;

    _state.setStatus(false, 'initing');
    _state.clearApis();

    // 查找 API
    final target = _state.list.cast<UserApiInfo?>().firstWhere(
          (api) => api?.id == apiId,
          orElse: () => null,
        );

    if (target == null) {
      _state.setStatus(false, 'API 不存在');
      return;
    }

    // 获取脚本
    final script = await _getApiScript(apiId);
    if (script == null || script.isEmpty) {
      _state.setStatus(false, '脚本不存在');
      return;
    }

    // 创建运行时并初始化
    UserApiRuntime? runtime;
    try {
      runtime = UserApiRuntime();
      final result = await runtime.init(target, script);

      if (result && runtime.apiInfo != null) {
        final apiInfo = runtime.apiInfo!;
        _runtime = runtime;
        _state.setCurrentApi(apiId);
        _state.setStatus(true, null);
        _state.setApis(apiInfo.sources ?? {}, runtime.apiInfo!.sources?.map(
          (k, v) => MapEntry(k, v.qualitys),
        ) ?? {});

        // 更新 API 信息
        _state.updateApiInfo(apiId, apiInfo);
        await _saveApiList();

        notifyListeners();
        debugPrint('[UserApiManager] ✅ 用户API初始化成功: ${apiInfo.sources?.keys.toList()}');
      } else {
        // 初始化失败，清理运行时
        runtime.dispose();
        _state.setStatus(false, '初始化失败');
        debugPrint('[UserApiManager] ❌ 用户API初始化失败');
      }
    } catch (e) {
      // 异常时确保运行时被清理
      runtime?.dispose();
      _runtime = null;
      _state.setStatus(false, '初始化异常: $e');
      debugPrint('[UserApiManager] ❌ 用户API初始化异常: $e');
    }
  }

  /// 销毁当前 API
  void destroyUserApi() {
    _runtime?.dispose();
    _runtime = null;
    _state.setCurrentApi(null);
    _state.setStatus(false, null);
    _state.clearApis();
    notifyListeners();
  }

  /// 移除 API
  Future<void> removeUserApi(List<String> ids) async {
    for (final id in ids) {
      _state.removeUserApi(id);
      await _removeApiScript(id);
    }
    await _saveApiList();
  }

  /// 获取播放链接
  Future<String> getMusicUrl({
    required String source,
    required Map<String, dynamic> musicInfo,
    required String quality,
  }) async {
    if (_runtime == null || !_runtime!.isInitialized) {
      throw Exception('用户 API 未初始化');
    }

    return _runtime!.getMusicUrl(
      source: source,
      musicInfo: musicInfo,
      quality: quality,
    );
  }

  /// 获取歌词
  Future<Map<String, dynamic>> getLyric({
    required String source,
    required Map<String, dynamic> musicInfo,
  }) async {
    if (_runtime == null || !_runtime!.isInitialized) {
      return {};
    }

    return _runtime!.getLyric(
      source: source,
      musicInfo: musicInfo,
    );
  }

  /// 获取封面
  Future<String> getPic({
    required String source,
    required Map<String, dynamic> musicInfo,
  }) async {
    if (_runtime == null || !_runtime!.isInitialized) {
      return '';
    }

    return _runtime!.getPic(
      source: source,
      musicInfo: musicInfo,
    );
  }

  /// 测试 API
  Future<bool> testApi(String apiId) async {
    final script = await _getApiScript(apiId);
    if (script == null || script.isEmpty) return false;

    final info = _state.list.cast<UserApiInfo?>().firstWhere(
          (api) => api?.id == apiId,
          orElse: () => null,
        );
    if (info == null) return false;

    final runtime = UserApiRuntime();
    try {
      final result = await runtime.init(info, script);
      runtime.dispose();
      return result;
    } catch (e) {
      runtime.dispose();
      return false;
    }
  }

  /// 检查源是否由用户 API 提供
  bool isUserApiSource(String source) {
    return _state.apis.containsKey(source);
  }

  @override
  void dispose() {
    _runtime?.dispose();
    super.dispose();
  }
}
