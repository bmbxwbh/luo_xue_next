import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// URL 缓存系统 — 缓存音乐播放 URL，减少重复请求
/// 对齐洛雪音乐的 URL 缓存逻辑
class UrlCache {
  static const String _prefix = 'music_url_';
  static const int _defaultExpireHours = 24;

  /// 获取缓存的 URL，过期返回 null
  static Future<String?> getUrl(String source, dynamic songmid, String quality) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${source}_${songmid}_$quality';
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final expireAt = data['expireAt'] as int?;
      final url = data['url'] as String?;

      if (url == null || url.isEmpty) return null;

      // 检查是否过期
      if (expireAt != null && DateTime.now().millisecondsSinceEpoch > expireAt) {
        await prefs.remove(key);
        return null;
      }

      return url;
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }

  /// 缓存 URL，默认 24 小时过期
  static Future<void> setUrl(String source, dynamic songmid, String quality, String url, {int? expireHours}) async {
    if (url.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${source}_${songmid}_$quality';
    final hours = expireHours ?? _defaultExpireHours;
    final expireAt = DateTime.now().millisecondsSinceEpoch + hours * 3600 * 1000;

    final data = jsonEncode({
      'url': url,
      'expireAt': expireAt,
    });

    await prefs.setString(key, data);
  }

  /// 清除所有 URL 缓存
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
