/// 网易云音乐搜索提示 — 对齐洛雪音乐 wy/tipSearch
import '../../utils/http_client.dart';

class WyTipSearch {
  /// 获取搜索建议
  static Future<List<String>> search(String keyword, {int retryNum = 0}) async {
    if (retryNum > 2) throw Exception('try max num');
    if (keyword.trim().isEmpty) return [];

    try {
      final resp = await HttpClient.get(
        'http://music.163.com/api/search/suggest/web?keyword=${Uri.encodeComponent(keyword)}&limit=10',
        headers: {
          'Referer': 'http://music.163.com/',
        },
      );

      if (resp.statusCode != 200 || resp.jsonBody == null) {
        return search(keyword, retryNum: retryNum + 1);
      }

      final body = resp.jsonBody;
      if (body is! Map) return search(keyword, retryNum: retryNum + 1);

      if (body['code'] != 200) return [];

      final result = body['result'];
      if (result == null || result is! Map) return [];

      final songs = result['songs'];
      if (songs == null || songs is! List) return [];

      final list = <String>[];
      for (final item in songs) {
        if (item is Map) {
          final name = item['name']?.toString() ?? '';
          final artists = item['artists'];
          String singer = '';
          if (artists is List && artists.isNotEmpty) {
            singer = artists.map((a) => a['name']?.toString() ?? '').where((n) => n.isNotEmpty).join('、');
          }
          final display = singer.isNotEmpty ? '$name - $singer' : name;
          if (display.isNotEmpty) {
            list.add(display);
          }
        }
      }
      return list;
    } catch (e) {
      return search(keyword, retryNum: retryNum + 1);
    }
  }
}
