/// 歌单数据缓存 — 减少重复网络请求
///
/// 用途：缓存首页推荐歌单列表，只有数据变化时才重新加载
/// 缓存策略：
///   1. 歌单列表数据存 SharedPreferences，带内容 hash
///   2. 分类标签缓存
///   3. 请求前先检查本地缓存，hash 一致则不请求
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist_info.dart';
import '../models/enums.dart';

class PlaylistCache {
  static const _prefix = 'pl_cache_';
  static const _catPrefix = 'pl_cat_';

  /// 获取缓存的歌单列表
  static Future<List<PlaylistInfo>?> getList(String source, String? tagId, int page) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_prefix}${source}_${tagId ?? "all"}_$page';
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final expireAt = data['expireAt'] as int?;
      if (expireAt != null && DateTime.now().millisecondsSinceEpoch > expireAt) {
        await prefs.remove(key);
        return null;
      }
      final list = (data['list'] as List?) ?? [];
      return list.map((item) => PlaylistInfo.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }

  /// 缓存歌单列表（默认 6 小时过期）
  static Future<void> setList(String source, String? tagId, int page, List<PlaylistInfo> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_prefix}${source}_${tagId ?? "all"}_$page';
    final expireAt = DateTime.now().millisecondsSinceEpoch + 6 * 3600 * 1000;
    final data = jsonEncode({
      'list': playlists.map((p) => p.toJson()).toList(),
      'hash': _hashList(playlists),
      'expireAt': expireAt,
    });
    await prefs.setString(key, data);
  }

  /// 检查数据是否有变化（通过 hash 对比）
  static Future<bool> hasChanged(String source, String? tagId, int page, List<PlaylistInfo> newPlaylists) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_prefix}${source}_${tagId ?? "all"}_$page';
    final raw = prefs.getString(key);
    if (raw == null) return true;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final oldHash = data['hash'] as String? ?? '';
      final newHash = _hashList(newPlaylists);
      return oldHash != newHash;
    } catch (_) {
      return true;
    }
  }

  /// 缓存分类标签（默认 24 小时过期）
  static Future<void> setCategories(String source, List<Map<String, dynamic>> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_catPrefix}$source';
    final expireAt = DateTime.now().millisecondsSinceEpoch + 24 * 3600 * 1000;
    await prefs.setString(key, jsonEncode({'list': categories, 'expireAt': expireAt}));
  }

  /// 获取缓存的分类标签
  static Future<List<Map<String, dynamic>>?> getCategories(String source) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_catPrefix}$source';
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final expireAt = data['expireAt'] as int?;
      if (expireAt != null && DateTime.now().millisecondsSinceEpoch > expireAt) {
        await prefs.remove(key);
        return null;
      }
      return (data['list'] as List?)?.cast<Map<String, dynamic>>();
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }

  /// 计算列表内容 hash
  static String _hashList(List<PlaylistInfo> playlists) {
    final ids = playlists.map((p) => '${p.id}:${p.name}:${p.img}').join(',');
    return sha256.convert(utf8.encode(ids)).toString().substring(0, 16);
  }

  /// 清除所有缓存
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix) || k.startsWith(_catPrefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
