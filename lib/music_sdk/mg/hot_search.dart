import '../../utils/http_client.dart';

/// 咪咕音乐热搜 — 对齐 LX Music mg/hotSearch.js
/// API: http://jadeite.migu.cn:7090/music_search/v3/search/hotword
class MgHotSearch {
  /// 获取热搜词列表
  static Future<List<String>> getHotSearch() async {
    final resp = await HttpClient.get(
      'http://jadeite.migu.cn:7090/music_search/v3/search/hotword',
    );

    if (resp.statusCode != 200 || resp.jsonBody == null) {
      throw Exception('获取咪咕热搜失败');
    }

    final body = resp.jsonBody;
    if (body['code'] != '000000') {
      throw Exception('咪咕热搜API错误');
    }

    final hotwords = body['data']?['hotwords'] as List? ?? [];
    if (hotwords.isEmpty) return [];

    final hotwordList = hotwords[0]['hotwordList'] as List? ?? [];
    return hotwordList
        .where((item) => item['resourceType'] == 'song')
        .map<String>((item) => item['word']?.toString() ?? '')
        .where((w) => w.isNotEmpty)
        .toList();
  }
}
