/// 酷我搜索提示 — 对齐洛雪音乐 kw/tipSearch
import '../../utils/http_client.dart';

class KwTipSearch {
  /// 获取搜索建议
  static Future<List<String>> search(String keyword, {int retryNum = 0}) async {
    if (retryNum > 2) throw Exception('try max num');
    if (keyword.trim().isEmpty) return [];

    try {
      final resp = await HttpClient.get(
        'http://www.kuwo.cn/api/www/search/searchKey?key=${Uri.encodeComponent(keyword)}',
        headers: {
          'Referer': 'http://www.kuwo.cn/',
          'csrf': '',
        },
      );

      if (resp.statusCode != 200 || resp.jsonBody == null) {
        return search(keyword, retryNum: retryNum + 1);
      }

      final body = resp.jsonBody;
      if (body is! Map) return search(keyword, retryNum: retryNum + 1);

      if (body['code'] != 200) return [];

      final data = body['data'];
      if (data == null || data is! List) return [];

      final list = <String>[];
      for (final item in data) {
        if (item is Map) {
          final keyStr = item['KEY']?.toString() ?? '';
          if (keyStr.isNotEmpty) {
            list.add(keyStr);
          }
        }
      }
      return list;
    } catch (e) {
      return search(keyword, retryNum: retryNum + 1);
    }
  }
}
