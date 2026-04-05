/// 咪咕搜索提示 — 对齐洛雪音乐 mg/tipSearch
import '../../utils/http_client.dart';

class MgTipSearch {
  /// 获取搜索建议
  static Future<List<String>> search(String keyword, {int retryNum = 0}) async {
    if (retryNum > 2) throw Exception('try max num');
    if (keyword.trim().isEmpty) return [];

    try {
      final resp = await HttpClient.get(
        'https://m.music.migu.cn/migu/remoting/autocomplete_tag?keyword=${Uri.encodeComponent(keyword)}',
      );

      if (resp.statusCode != 200 || resp.jsonBody == null) {
        return search(keyword, retryNum: retryNum + 1);
      }

      final body = resp.jsonBody;
      if (body is! Map) return search(keyword, retryNum: retryNum + 1);

      if (body['returnCode'] != '000000' && body['result'] != 100) return [];

      final result = body['result'] is List
          ? body['result'] as List
          : body['data'] as List? ?? [];

      if (result is! List) return [];

      final list = <String>[];
      for (final item in result) {
        if (item is Map) {
          final keywordStr = item['keyword']?.toString() ?? item['title']?.toString() ?? '';
          if (keywordStr.isNotEmpty) {
            list.add(keywordStr);
          }
        }
      }
      return list;
    } catch (e) {
      return search(keyword, retryNum: retryNum + 1);
    }
  }
}
