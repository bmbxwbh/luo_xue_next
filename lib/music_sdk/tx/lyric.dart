import 'dart:convert';
import '../../utils/http_client.dart';
import '../../models/lyric_info.dart';

/// QQ音乐歌词 — 对齐 LX Music tx/lyric.js
/// API: https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg
class TxLyric {
  /// 获取歌词
  /// 返回 LyricInfo 包含原文和翻译
  static Future<LyricInfo> getLyric(String songmid) async {
    final resp = await HttpClient.get(
      'https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=$songmid&g_tk=5381&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8&platform=yqq',
      headers: {'Referer': 'https://y.qq.com/portal/player.html'},
    );

    if (resp.statusCode != 200 || resp.jsonBody == null) {
      throw Exception('获取QQ音乐歌词失败');
    }

    final body = resp.jsonBody;
    if (body['code'] != 0 || body['lyric'] == null) {
      throw Exception('QQ音乐歌词为空');
    }

    // Base64解码歌词
    final lyric = _decodeBase64(body['lyric']);
    final tlyric = body['trans'] != null ? _decodeBase64(body['trans']) : '';

    return LyricInfo(
      lyric: lyric,
      tlyric: tlyric,
    );
  }

  /// Base64解码并处理HTML实体
  static String _decodeBase64(String? encoded) {
    if (encoded == null || encoded.isEmpty) return '';
    try {
      final decoded = utf8.decode(base64.decode(encoded));
      // 处理HTML实体编码
      return decoded
          .replaceAll('&#10;', '\n')
          .replaceAll('&#13;', '\r')
          .replaceAll('&#32;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&apos;', "'")
          .replaceAll('&quot;', '"');
    } catch (e) {
      return '';
    }
  }
}
