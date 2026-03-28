/// 酷狗搜索提示 — 对齐洛雪音乐 kg/tipSearch
import 'dart:convert';
import '../../utils/http_client.dart';

class KgTipSearch {
  /// 获取搜索建议
  static Future<List<String>> search(String keyword, {int retryNum = 0}) async {
    if (retryNum > 2) throw Exception('try max num');
    if (keyword.trim().isEmpty) return [];

    try {
      final resp = await HttpClient.get(
        'http://searchtip.kugou.com/getTip?keyword=${Uri.encodeComponent(keyword)}&type=1&userid=0&appid=1005&clientver=10026',
      );

      if (resp.statusCode != 200 || resp.jsonBody == null) {
        return search(keyword, retryNum: retryNum + 1);
      }

      final body = resp.jsonBody;
      if (body is! Map) return search(keyword, retryNum: retryNum + 1);

      final data = body['data'];
      if (data == null || data is! Map) return [];

      final record = data['Record'];
      if (record == null || record is! List) return [];

      final list = <String>[];
      for (final item in record) {
        if (item is Map) {
          final keywordStr = item['HintInfo']?.toString() ?? item['keyword']?.toString() ?? '';
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
