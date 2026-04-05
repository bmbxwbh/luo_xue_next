/// QQ音乐搜索提示 — 对齐洛雪音乐 tx/tipSearch
import '../../utils/http_client.dart';

class TxTipSearch {
  /// 获取搜索建议
  static Future<List<String>> search(String keyword, {int retryNum = 0}) async {
    if (retryNum > 2) throw Exception('try max num');
    if (keyword.trim().isEmpty) return [];

    try {
      final resp = await HttpClient.get(
        'https://c.y.qq.com/splcloud/fcgi-bin/smartbox_new.fcg?key=${Uri.encodeComponent(keyword)}&format=json',
        headers: {
          'Referer': 'https://y.qq.com/',
        },
      );

      if (resp.statusCode != 200 || resp.jsonBody == null) {
        return search(keyword, retryNum: retryNum + 1);
      }

      final body = resp.jsonBody;
      if (body is! Map) return search(keyword, retryNum: retryNum + 1);

      if (body['code'] != 0) return [];

      final data = body['data'];
      if (data == null || data is! Map) return [];

      final songData = data['song'];
      if (songData == null || songData is! Map) return [];

      final itemList = songData['itemlist'];
      if (itemList == null || itemList is! List) return [];

      final list = <String>[];
      for (final item in itemList) {
        if (item is Map) {
          final name = item['name']?.toString() ?? '';
          final singer = item['singer']?.toString() ?? '';
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
