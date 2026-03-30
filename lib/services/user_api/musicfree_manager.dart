/// MusicFree 插件管理器 — 管理 MF 格式插件的导入/列表/删除
///
/// 用途：类似 UserApiManager，但专门管理 MusicFree 格式的插件。
/// 数据存储使用 SharedPreferences，key 前缀为 mf_plugin_。
///
/// 关键逻辑：
/// - 导入插件：检测格式 → 加载到 MusicFreeRuntime → 存储
/// - 插件列表：从 SharedPreferences 加载
/// - 获取播放链接：调用插件的 getMediaSource
/// - 获取搜索结果：调用插件的 search
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'musicfree_runtime.dart';
import 'plugin_format_detector.dart';

/// MF 插件信息
class MusicFreePluginInfo {
  final String id;
  final String name;
  final String? version;
  final String? description;
  final String path;
  final String hash;
  final List<String> methods;

  const MusicFreePluginInfo({
    required this.id,
    required this.name,
    this.version,
    this.description,
    required this.path,
    required this.hash,
    required this.methods,
  });

  bool get supportsSearch => methods.contains('search');
  bool get supportsGetMediaSource => methods.contains('getMediaSource');
  bool get supportsGetLyric => methods.contains('getLyric');

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (version != null) 'version': version,
        if (description != null) 'description': description,
        'path': path,
        'hash': hash,
        'methods': methods,
      };

  factory MusicFreePluginInfo.fromJson(Map<String, dynamic> json) {
    return MusicFreePluginInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      version: json['version'] as String?,
      description: json['description'] as String?,
      path: json['path'] as String? ?? '',
      hash: json['hash'] as String? ?? '',
      methods: (json['methods'] as List?)?.cast<String>() ?? [],
    );
  }
}

/// MusicFree 插件管理器
class MusicFreeManager extends ChangeNotifier {
  static const _keyPluginList = 'mf_plugin_list';
  static const _keyPluginPrefix = 'mf_plugin_';

  /// 插件信息列表
  final List<MusicFreePluginInfo> _plugins = [];

  /// 当前运行时
  MusicFreeRuntime? _runtime;

  /// 插件脚本内容缓存
  final Map<String, String> _scriptCache = {};

  /// 获取插件列表
  List<MusicFreePluginInfo> get plugins => List.unmodifiable(_plugins);

  /// 当前运行时中的插件
  MusicFreePlugin? get currentPlugin => _runtime?.currentPlugin;

  /// 是否有可用的 getMediaSource 插件
  bool get hasMediaSourcePlugin =>
      _plugins.any((p) => p.supportsGetMediaSource);

  /// 获取支持 getMediaSource 的插件列表
  List<MusicFreePluginInfo> get mediaSourcePlugins =>
      _plugins.where((p) => p.supportsGetMediaSource).toList();

  /// 获取支持 search 的插件列表
  List<MusicFreePluginInfo> get searchablePlugins =>
      _plugins.where((p) => p.supportsSearch).toList();

  /// 初始化 — 从 SharedPreferences 加载插件列表
  Future<void> init() async {
    await _loadPluginList();
    // 自动加载第一个有 getMediaSource 的插件
    if (_plugins.isNotEmpty) {
      final mediaSourcePlugin = _plugins.firstWhere(
        (p) => p.supportsGetMediaSource,
        orElse: () => _plugins.first,
      );
      try {
        await setActivePlugin(mediaSourcePlugin.id);
      } catch (e) {
        debugPrint('[MF] 自动加载插件失败: $e');
      }
    }
  }

  /// 从 SharedPreferences 加载插件列表
  Future<void> _loadPluginList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getString(_keyPluginList);
      if (listJson == null) return;

      final list = jsonDecode(listJson) as List;
      _plugins.clear();
      for (final item in list) {
        _plugins.add(MusicFreePluginInfo.fromJson(item as Map<String, dynamic>));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[MF] 加载插件列表失败: $e');
    }
  }

  /// 保存插件列表
  Future<void> _savePluginList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyPluginList,
        jsonEncode(_plugins.map((p) => p.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[MF] 保存插件列表失败: $e');
    }
  }

  /// 保存插件脚本
  Future<void> _savePluginScript(String id, String script) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_keyPluginPrefix$id', script);
      _scriptCache[id] = script;
    } catch (e) {
      debugPrint('[MF] 保存插件脚本失败: $e');
    }
  }

  /// 获取插件脚本
  Future<String?> _getPluginScript(String id) async {
    if (_scriptCache.containsKey(id)) return _scriptCache[id];
    try {
      final prefs = await SharedPreferences.getInstance();
      final script = prefs.getString('$_keyPluginPrefix$id');
      if (script != null) _scriptCache[id] = script;
      return script;
    } catch (e) {
      debugPrint('[MF] 获取插件脚本失败: $e');
      return null;
    }
  }

  /// 导入 MF 插件（从 JS 脚本内容）
  ///
  /// [script] JS 脚本内容
  /// 返回导入结果 {success, message, pluginInfo?}
  Future<Map<String, dynamic>> importPlugin(String script) async {
    // 1. 检测格式
    final formatResult = detectPluginFormat(script);
    if (!formatResult.isMusicFree) {
      return {
        'success': false,
        'message': formatResult.isLx
            ? '这是洛雪脚本格式，请在洛雪模式下导入'
            : '无法识别的插件格式',
      };
    }

    final meta = formatResult.mfMeta!;
    if (meta.platform.isEmpty) {
      return {'success': false, 'message': '插件缺少 platform 字段'};
    }

    // 2. 检查是否已安装（通过 hash 去重）
    final hash = sha256.convert(utf8.encode(script)).toString();
    if (_plugins.any((p) => p.hash == hash)) {
      return {'success': false, 'message': '插件已安装'};
    }

    // 3. 检查是否有同名插件（版本更新）
    final existingIndex = _plugins.indexWhere((p) => p.name == meta.platform);

    // 4. 创建插件信息
    final id = 'mf_${DateTime.now().millisecondsSinceEpoch}';
    final pluginInfo = MusicFreePluginInfo(
      id: id,
      name: meta.platform,
      version: meta.version,
      path: id,
      hash: hash,
      methods: meta.methods.map((m) => m.name).toList(),
    );

    // 5. 替换旧版本
    if (existingIndex >= 0) {
      final oldId = _plugins[existingIndex].id;
      _plugins.removeAt(existingIndex);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_keyPluginPrefix$oldId');
      _scriptCache.remove(oldId);
    }

    // 6. 保存
    _plugins.add(pluginInfo);
    await _savePluginScript(id, script);
    await _savePluginList();
    notifyListeners();

    debugPrint('[MF] 插件导入成功: ${meta.platform} (${meta.methods.map((m) => m.name).toList()})');
    return {
      'success': true,
      'message': '导入成功',
      'pluginInfo': pluginInfo.toJson(),
    };
  }

  /// 设置当前活动插件
  ///
  /// [pluginId] 插件 ID
  Future<void> setActivePlugin(String pluginId) async {
    // 销毁旧的运行时
    _runtime?.dispose();
    _runtime = null;

    final info = _plugins.cast<MusicFreePluginInfo?>().firstWhere(
          (p) => p?.id == pluginId,
          orElse: () => null,
        );
    if (info == null) throw Exception('插件不存在');

    final script = await _getPluginScript(pluginId);
    if (script == null || script.isEmpty) throw Exception('插件脚本不存在');

    final runtime = MusicFreeRuntime();
    final success = await runtime.init(script, info.path);
    if (success) {
      _runtime = runtime;
      debugPrint('[MF] 插件激活成功: ${info.name}');
    } else {
      runtime.dispose();
      throw Exception('插件初始化失败');
    }
  }

  /// 删除插件
  Future<void> removePlugin(String pluginId) async {
    final index = _plugins.indexWhere((p) => p.id == pluginId);
    if (index < 0) return;

    final info = _plugins[index];
    _plugins.removeAt(index);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPluginPrefix$pluginId');
    _scriptCache.remove(pluginId);

    // 如果删除的是当前活动插件，销毁运行时
    if (_runtime?.currentPlugin?.name == info.name) {
      _runtime?.dispose();
      _runtime = null;
    }

    await _savePluginList();
    notifyListeners();
  }

  /// 通过平台名获取插件
  MusicFreePluginInfo? getByName(String platform) {
    return _plugins.cast<MusicFreePluginInfo?>().firstWhere(
          (p) => p?.name == platform,
          orElse: () => null,
        );
  }

  /// 获取播放链接
  ///
  /// [musicItem] MF 格式的音乐项
  /// [quality] 音质
  /// [pluginName] 可选，指定使用哪个插件
  Future<Map<String, dynamic>?> getMediaSource({
    required Map<String, dynamic> musicItem,
    String quality = 'standard',
    String? pluginName,
  }) async {
    // 如果指定了插件名，先切换到该插件
    if (pluginName != null && _runtime?.currentPlugin?.name != pluginName) {
      final info = getByName(pluginName);
      if (info != null) {
        try {
          await setActivePlugin(info.id);
        } catch (e) {
          debugPrint('[MF] 切换插件失败: $e');
          return null;
        }
      }
    }

    // 如果没有运行时，尝试加载第一个可用的插件
    if (_runtime == null && _plugins.isNotEmpty) {
      final mediaPlugin = _plugins.firstWhere(
        (p) => p.supportsGetMediaSource,
        orElse: () => _plugins.first,
      );
      try {
        await setActivePlugin(mediaPlugin.id);
      } catch (e) {
        debugPrint('[MF] 自动加载插件失败: $e');
        return null;
      }
    }

    if (_runtime == null) return null;
    return _runtime!.getMediaSource(musicItem, quality);
  }

  /// 搜索
  Future<List<Map<String, dynamic>>> search(
    String query,
    int page,
    String type, {
    String? pluginName,
  }) async {
    if (pluginName != null && _runtime?.currentPlugin?.name != pluginName) {
      final info = getByName(pluginName);
      if (info != null) {
        try {
          await setActivePlugin(info.id);
        } catch (e) {
          return [];
        }
      }
    }

    if (_runtime == null) return [];
    return _runtime!.search(query, page, type);
  }

  /// 获取歌词
  Future<Map<String, dynamic>?> getLyric(
    Map<String, dynamic> musicItem, {
    String? pluginName,
  }) async {
    if (pluginName != null && _runtime?.currentPlugin?.name != pluginName) {
      final info = getByName(pluginName);
      if (info != null) {
        try {
          await setActivePlugin(info.id);
        } catch (e) {
          return null;
        }
      }
    }

    if (_runtime == null) return null;
    return _runtime!.getLyric(musicItem);
  }

  @override
  void dispose() {
    _runtime?.dispose();
    super.dispose();
  }
}
