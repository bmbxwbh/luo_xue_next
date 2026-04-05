import '../../utils/http_client.dart';
import '../../utils/eapi_encryptor.dart';

/// 网易云音乐热搜 — 对齐 LX Music wy/hotSearch.js
/// EAPI: https://interface3.music.163.com/eapi/search/chart/detail
class WyHotSearch {
  /// 获取热搜词列表
  static Future<List<String>> getHotSearch() async {
    final data = {'id': 'HOT_SEARCH_SONG#@#'};
    final form = EapiEncryptor.eapi('/api/search/chart/detail', data);

    final resp = await HttpClient.postForm(
      'https://interface3.music.163.com/eapi/search/chart/detail',
      headers: {
        'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36',
        'origin': 'https://music.163.com',
      },
      body: form,
    );

    if (resp.statusCode != 200 || resp.jsonBody == null) {
      throw Exception('获取网易云热搜失败');
    }

    final body = resp.jsonBody;
    if (body['code'] != 200) {
      throw Exception('网易云热搜API错误');
    }

    final itemList = body['data']?['itemList'] as List? ?? [];
    return itemList
        .map<String>((item) => item['searchWord']?.toString() ?? '')
        .where((w) => w.isNotEmpty)
        .toList();
  }
}
