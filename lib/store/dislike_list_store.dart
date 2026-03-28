import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 不喜欢列表存储 — 对齐洛雪音乐的不喜欢列表功能
/// 持久化存储不喜欢的歌曲名/歌手组合，播放时自动跳过
class DislikeListStore extends ChangeNotifier {
  static const String _key = 'dislike_list';

  /// 不喜欢列表 [{name: 歌曲名, singer: 歌手名}]
  final List<Map<String, String>> _list = [];

  List<Map<String, String>> get list => List.unmodifiable(_list);

  bool _initialized = false;

  /// 初始化，从本地加载数据
  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        _list.clear();
        for (final item in decoded) {
          if (item is Map) {
            _list.add({
              'name': (item['name'] ?? '').toString(),
              'singer': (item['singer'] ?? '').toString(),
            });
          }
        }
      } catch (_) {}
    }
    _initialized = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_list));
  }

  /// 添加不喜欢歌曲
  Future<void> add(String name, String singer) async {
    final n = name.trim();
    final s = singer.trim();
    if (n.isEmpty && s.isEmpty) return;

    // 去重检查
    if (_list.any((item) => item['name'] == n && item['singer'] == s)) return;

    _list.add({'name': n, 'singer': s});
    await _save();
    notifyListeners();
  }

  /// 移除不喜欢歌曲
  Future<void> remove(String name, String singer) async {
    final n = name.trim();
    final s = singer.trim();
    _list.removeWhere((item) => item['name'] == n && item['singer'] == s);
    await _save();
    notifyListeners();
  }

  /// 判断歌曲是否在不喜欢列表中
  bool isDisliked(String name, String singer) {
    final n = name.trim();
    final s = singer.trim();
    return _list.any((item) => item['name'] == n && item['singer'] == s);
  }

  /// 获取不喜欢列表
  List<Map<String, String>> getList() {
    return List.unmodifiable(_list);
  }

  /// 清空不喜欢列表
  Future<void> clear() async {
    _list.clear();
    await _save();
    notifyListeners();
  }
}
