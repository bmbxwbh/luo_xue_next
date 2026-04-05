/// 酷狗音乐歌词 — 对齐 LX Music kg/lyric.js
import 'dart:convert';
import 'dart:io';
import '../../utils/http_client.dart';
import '../../utils/format_util.dart';

class KgLyric {
  static final _headers = {
    'KG-RC': '1',
    'KG-THash': 'expand_search_manager.cpp:852736169:451',
    'User-Agent': 'KuGou2012-9020-ExpandSearchManager',
  };

  /// 获取时长秒数
  static int getIntv(String? interval) {
    if (interval == null || interval.isEmpty) return 0;
    final parts = interval.split(':');
    int result = 0;
    int unit = 1;
    for (int i = parts.length - 1; i >= 0; i--) {
      result += int.tryParse(parts[i])! * unit;
      unit *= 60;
    }
    return result;
  }

  /// 搜索歌词
  static Future<Map<String, dynamic>?> _searchLyric(String name, String hash, int time, {int retryNum = 0}) async {
    if (retryNum > 5) throw Exception('歌词获取失败');
    try {
      final resp = await HttpClient.get(
        'http://lyrics.kugou.com/search?ver=1&man=yes&client=pc&keyword=${Uri.encodeComponent(name)}&hash=$hash&timelength=$time&lrctxt=1',
        headers: _headers,
      );
      if (resp.statusCode != 200) return _searchLyric(name, hash, time, retryNum: retryNum + 1);
      final body = resp.jsonBody;
      final candidates = body['candidates'];
      if (candidates is List && candidates.isNotEmpty) {
        final info = candidates[0];
        final krctype = info['krctype'];
        final contenttype = info['contenttype'];
        return {
          'id': info['id'],
          'accessKey': info['accesskey'],
          'fmt': (krctype == 1 && contenttype != 1) ? 'krc' : 'lrc',
        };
      }
      return null;
    } catch (_) {
      return _searchLyric(name, hash, time, retryNum: retryNum + 1);
    }
  }

  /// 下载歌词
  static Future<Map<String, dynamic>> _getLyricDownload(dynamic id, String accessKey, String fmt, {int retryNum = 0}) async {
    if (retryNum > 5) throw Exception('歌词获取失败');
    try {
      final resp = await HttpClient.get(
        'http://lyrics.kugou.com/download?ver=1&client=pc&id=$id&accesskey=$accessKey&fmt=$fmt&charset=utf8',
        headers: _headers,
      );
      if (resp.statusCode != 200) return _getLyricDownload(id, accessKey, fmt, retryNum: retryNum + 1);
      final body = resp.jsonBody;

      switch (body['fmt']) {
        case 'krc':
          // KRC格式需要解密 — 返回原始base64内容，由调用方处理
          return {
            'lyric': body['content'] ?? '',
            'tlyric': '',
            'rlyric': '',
            'lxlyric': '',
            'fmt': 'krc',
          };
        case 'lrc':
          final content = body['content'] ?? '';
          final decoded = utf8.decode(base64Decode(content));
          return {
            'lyric': decoded,
            'tlyric': '',
            'rlyric': '',
            'lxlyric': '',
            'fmt': 'lrc',
          };
        default:
          throw Exception('未知歌词格式: ${body['fmt']}');
      }
    } catch (_) {
      return _getLyricDownload(id, accessKey, fmt, retryNum: retryNum + 1);
    }
  }

  /// 获取歌词 (主入口)
  static Future<Map<String, dynamic>> getLyric(Map<String, dynamic> songInfo) async {
    final name = songInfo['name'] ?? '';
    final hash = songInfo['hash'] ?? '';
    final interval = songInfo['_interval'] ?? getIntv(songInfo['interval']);

    final searchResult = await _searchLyric(name, hash, interval);
    if (searchResult == null) throw Exception('Get lyric failed');

    return _getLyricDownload(searchResult['id'], searchResult['accessKey'], searchResult['fmt']);
  }
}
