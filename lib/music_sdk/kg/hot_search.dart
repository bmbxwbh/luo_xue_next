/// 酷狗热搜 — 对齐 LX Music kg/hotSearch.js
import '../../utils/http_client.dart';
import '../../utils/format_util.dart';

class KgHotSearch {
  /// 获取热搜词列表
  static Future<List<String>> getList({int retryNum = 0}) async {
    if (retryNum > 2) throw Exception('try max num');

    try {
      final resp = await HttpClient.get(
        'http://gateway.kugou.com/api/v3/search/hot_tab?signature=ee44edb9d7155821412d220bcaf509dd&appid=1005&clientver=10026&plat=0',
        headers: {
          'dfid': '1ssiv93oVqMp27cirf2CvoF1',
          'mid': '156798703528610303473757548878786007104',
          'clienttime': '1584257267',
          'x-router': 'msearch.kugou.com',
          'user-agent': 'Android9-AndroidPhone-10020-130-0-searchrecommendprotocol-wifi',
          'kg-rc': '1',
        },
      );

      if (resp.statusCode != 200) throw Exception('获取热搜词失败');
      final body = resp.jsonBody;
      if (body == null || body['errcode'] != 0) throw Exception('获取热搜词失败');

      return _filterList(body['data']['list'] as List);
    } catch (e) {
      return getList(retryNum: retryNum + 1);
    }
  }

  static List<String> _filterList(List rawList) {
    final list = <String>[];
    for (final item in rawList) {
      if (item['keywords'] is List) {
        for (final k in item['keywords']) {
          list.add(decodeName(k['keyword']?.toString()));
        }
      }
    }
    return list;
  }
}
