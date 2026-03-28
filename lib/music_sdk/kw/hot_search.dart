/// 酷我热搜 — 对齐 LX Music kw/hotSearch.js
import '../../utils/http_client.dart';

class KwHotSearch {
  /// 获取热搜词列表
  static Future<List<String>> getList({int retryNum = 0}) async {
    if (retryNum > 2) throw Exception('try max num');

    try {
      final resp = await HttpClient.get(
        'http://hotword.kuwo.cn/hotword.s?prod=kwplayer_ar_9.3.0.1&corp=kuwo&newver=2&vipver=9.3.0.1&source=kwplayer_ar_9.3.0.1_40.apk&p2p=1&notrace=0&uid=0&plat=kwplayer_ar&rformat=json&encoding=utf8&tabid=1',
        headers: {
          'User-Agent': 'Dalvik/2.1.0 (Linux; U; Android 9;)',
        },
      );

      if (resp.statusCode != 200) throw Exception('获取热搜词失败');
      final body = resp.jsonBody;
      if (body == null || body['status'] != 'ok') throw Exception('获取热搜词失败');

      return _filterList(body['tagvalue'] as List);
    } catch (e) {
      return getList(retryNum: retryNum + 1);
    }
  }

  static List<String> _filterList(List rawList) {
    return rawList.map<String>((item) => item['key']?.toString() ?? '').toList();
  }
}
