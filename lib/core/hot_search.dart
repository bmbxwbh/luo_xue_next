import '../models/enums.dart';
import '../utils/http_client.dart';

/// 热搜业务 — 对齐 LX Music core/hot_search.dart
class HotSearchService {

  /// 获取热搜词
  Future<List<String>> getHotSearch(MusicSource source) async {
    switch (source) {
      case MusicSource.kw:
        return _getKwHotSearch();
      case MusicSource.kg:
        return _getKgHotSearch();
      case MusicSource.tx:
        return _getTxHotSearch();
      case MusicSource.wy:
        return _getWyHotSearch();
      case MusicSource.mg:
      case MusicSource.local:
        return [];
        return _getMgHotSearch();
    }
  }

  /// 酷我热搜
  Future<List<String>> _getKwHotSearch() async {
    try {
      final url = 'http://www.kuwo.cn/api/www/search/searchHotKey';
      final resp = await HttpClient.get(url, headers: {
        'Referer': 'http://www.kuwo.cn/',
        'csrf': '',
      });

      if (!resp.ok || resp.jsonBody is! Map) return [];

      final data = resp.jsonBody as Map<String, dynamic>;
      if (data['code'] != 200 || data['data'] is! List) return [];

      return (data['data'] as List)
          .map((item) => item['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 酷狗热搜
  Future<List<String>> _getKgHotSearch() async {
    try {
      final url = 'https://www.kugou.com/yy/home/search/hot';
      final resp = await HttpClient.get(url);
      // 实际需要解析HTML
      return [];
    } catch (e) {
      return [];
    }
  }

  /// QQ音乐热搜
  Future<List<String>> _getTxHotSearch() async {
    try {
      final url = 'https://c.y.qq.com/splcloud/fcgi-bin/gethotkey.fcg?format=json';
      final resp = await HttpClient.get(url, headers: {'Referer': 'https://y.qq.com/'});

      if (!resp.ok || resp.jsonBody is! Map) return [];

      final data = resp.jsonBody as Map<String, dynamic>;
      if (data['data'] is! Map || data['data']['hotkey'] is! List) return [];

      return (data['data']['hotkey'] as List)
          .map((item) => item['k']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 网易云热搜
  Future<List<String>> _getWyHotSearch() async {
    try {
      final url = 'https://music.163.com/api/search/hot';
      final resp = await HttpClient.postForm(url, headers: {
        'Referer': 'https://music.163.com/',
      }, body: {'type': '1111'});

      if (!resp.ok || resp.jsonBody is! Map) return [];

      final data = resp.jsonBody as Map<String, dynamic>;
      if (data['result'] is! Map || data['result']['hots'] is! List) return [];

      return (data['result']['hots'] as List)
          .map((item) => item['first']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 咪咕热搜
  Future<List<String>> _getMgHotSearch() async {
    try {
      final url = 'https://m.music.migu.cn/migu/remoting/hot_word_tag';
      final resp = await HttpClient.get(url, headers: {
        'Referer': 'https://m.music.migu.cn/',
      });

      if (!resp.ok || resp.jsonBody is! Map) return [];

      final data = resp.jsonBody as Map<String, dynamic>;
      final list = data['data'] as List?;
      if (list == null) return [];

      return list
          .map((item) => item['keyword']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 获取所有支持热搜的音源
  List<MusicSource> get supportedSources {
    return [
      MusicSource.kw,
      MusicSource.kg,
      MusicSource.tx,
      MusicSource.wy,
      MusicSource.mg,
    ];
  }
}
