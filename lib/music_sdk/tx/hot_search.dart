import 'dart:convert';
import '../../utils/http_client.dart';

/// QQ音乐热搜 — 对齐 LX Music tx/hotSearch.js
/// API: POST https://u.y.qq.com/cgi-bin/musicu.fcg
class TxHotSearch {
  /// 获取热搜词列表
  static Future<List<String>> getHotSearch() async {
    final body = {
      'comm': {
        'ct': '19',
        'cv': '1803',
        'guid': '0',
        'patch': '118',
        'psrf_access_token_expiresAt': 0,
        'psrf_qqaccess_token': '',
        'psrf_qqopenid': '',
        'psrf_qqunionid': '',
        'tmeAppID': 'qqmusic',
        'tmeLoginType': 0,
        'uin': '0',
        'wid': '0',
      },
      'hotkey': {
        'method': 'GetHotkeyForQQMusicPC',
        'module': 'tencent_musicsoso_hotkey.HotkeyService',
        'param': {
          'search_id': '',
          'uin': 0,
        },
      },
    };

    final resp = await HttpClient.post(
      'https://u.y.qq.com/cgi-bin/musicu.fcg',
      headers: {'Referer': 'https://y.qq.com/portal/player.html'},
      body: jsonEncode(body),
    );

    if (resp.statusCode != 200 || resp.jsonBody == null) {
      throw Exception('获取QQ音乐热搜失败');
    }

    final json = resp.jsonBody;
    if (json['code'] != 0) {
      throw Exception('QQ音乐热搜API错误');
    }

    final hotkeyData = json['hotkey']?['data'];
    if (hotkeyData == null) return [];

    final vecHotkey = hotkeyData['vec_hotkey'] as List? ?? [];
    return vecHotkey
        .map<String>((item) => item['query']?.toString() ?? '')
        .where((q) => q.isNotEmpty)
        .toList();
  }
}
