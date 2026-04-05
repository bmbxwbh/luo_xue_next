/// 酷狗歌单 — 对齐 LX Music kg/songList.js
import '../../utils/http_client.dart';
import '../../utils/format_util.dart';

class KgSongList {
  /// 排序列表
  static const sortList = [
    {'name': '推荐', 'tid': 'recommend', 'id': '5'},
    {'name': '最热', 'tid': 'hot', 'id': '6'},
    {'name': '最新', 'tid': 'new', 'id': '7'},
    {'name': '热藏', 'tid': 'hot_collect', 'id': '3'},
    {'name': '飙升', 'tid': 'rise', 'id': '8'},
  ];

  /// 获取推荐歌单 URL
  static String _getInfoUrl([String? tagId]) {
    if (tagId != null && tagId.isNotEmpty) {
      return 'http://www2.kugou.kugou.com/yueku/v9/special/getSpecial?is_smarty=1&cdn=cdn&t=5&c=$tagId';
    }
    return 'http://www2.kugou.kugou.com/yueku/v9/special/getSpecial?is_smarty=1&';
  }

  /// 获取歌单列表 URL
  static String _getSongListUrl(String sortId, String? tagId, int page) {
    tagId ??= '';
    return 'http://www2.kugou.kugou.com/yueku/v9/special/getSpecial?is_ajax=1&cdn=cdn&t=$sortId&c=$tagId&p=$page';
  }

  /// 获取歌单详情 URL
  static String _getSongListDetailUrl(String id) {
    return 'http://www2.kugou.kugou.com/yueku/v9/special/single/$id-5-9999.html';
  }

  /// 获取推荐歌单
  static Future<List<Map<String, dynamic>>> getSongListRecommend({int retryNum = 0}) async {
    if (retryNum > 2) throw Exception('try max num');
    try {
      final resp = await HttpClient.post(
        'http://everydayrec.service.kugou.com/guess_special_recommend',
        headers: {
          'User-Agent': 'KuGou2012-8275-web_browser_event_handler',
        },
        body: {
          'appid': 1001,
          'clienttime': 1566798337219,
          'clientver': 8275,
          'key': 'f1f93580115bb106680d2375f8032d96',
          'mid': '21511157a05844bd085308bc76ef3343',
          'platform': 'pc',
          'userid': '262643156',
          'return_min': 6,
          'return_max': 15,
        },
      );
      final body = resp.jsonBody;
      if (body == null || body['status'] != 1) return getSongListRecommend(retryNum: retryNum + 1);
      return _filterList(body['data']['special_list'] as List);
    } catch (_) {
      return getSongListRecommend(retryNum: retryNum + 1);
    }
  }

  /// 获取歌单列表
  static Future<List<Map<String, dynamic>>> getSongList(String sortId, String? tagId, int page, {int retryNum = 0}) async {
    if (retryNum > 2) throw Exception('try max num');
    try {
      final resp = await HttpClient.get(_getSongListUrl(sortId, tagId, page));
      final body = resp.jsonBody;
      if (body == null || body['status'] != 1) return getSongList(sortId, tagId, page, retryNum: retryNum + 1);
      return _filterList(body['special_db'] as List);
    } catch (_) {
      return getSongList(sortId, tagId, page, retryNum: retryNum + 1);
    }
  }

  /// 获取标签
  static Future<Map<String, dynamic>> getTags({int retryNum = 0}) async {
    if (retryNum > 2) throw Exception('try max num');
    try {
      final resp = await HttpClient.get(_getInfoUrl());
      final body = resp.jsonBody;
      if (body == null || body['status'] != 1) return getTags(retryNum: retryNum + 1);
      return {
        'hotTag': _filterInfoHotTag(body['data']['hotTag']),
        'tags': _filterTagInfo(body['data']['tagids']),
        'source': 'kg',
      };
    } catch (_) {
      return getTags(retryNum: retryNum + 1);
    }
  }

  /// 获取歌单详情页 URL
  static String getDetailPageUrl(String id) {
    if (id.startsWith('http')) return id;
    final cleanId = id.replaceFirst('id_', '');
    return 'https://www.kugou.com/yy/special/single/$cleanId.html';
  }

  /// 搜索歌单
  static Future<Map<String, dynamic>> search(String text, int page, {int limit = 20}) async {
    final resp = await HttpClient.get(
      'http://msearchretry.kugou.com/api/v3/search/special?keyword=${Uri.encodeComponent(text)}&page=$page&pagesize=$limit&showtype=10&filter=0&version=7910&sver=2',
    );
    final body = resp.jsonBody;
    if (body == null || body['errcode'] != 0) throw Exception('搜索失败');
    return {
      'list': (body['data']['info'] as List).map((item) => {
        'play_count': formatPlayCount(item['playcount']),
        'id': 'id_${item['specialid']}',
        'author': item['nickname'],
        'name': item['specialname'],
        'img': item['imgurl'],
        'grade': item['grade'],
        'desc': item['intro'],
        'total': item['songcount'],
        'source': 'kg',
      }).toList(),
      'limit': limit,
      'total': body['data']['total'],
      'source': 'kg',
    };
  }

  static List<Map<String, dynamic>> _filterList(List rawData) {
    return rawData.map((item) => {
      'play_count': formatPlayCount(item['total_play_count'] ?? item['play_count']),
      'id': 'id_${item['specialid']}',
      'author': item['nickname'],
      'name': item['specialname'],
      'img': item['img'] ?? item['imgurl'],
      'total': item['songcount'],
      'grade': item['grade'],
      'desc': item['intro'],
      'source': 'kg',
    }).toList();
  }

  static List<Map<String, dynamic>> _filterInfoHotTag(Map<String, dynamic> rawData) {
    final result = <Map<String, dynamic>>[];
    rawData.forEach((key, tag) {
      if (tag is Map) {
        result.add({
          'id': tag['special_id'],
          'name': tag['special_name'],
          'source': 'kg',
        });
      }
    });
    return result;
  }

  static List<Map<String, dynamic>> _filterTagInfo(Map<String, dynamic> rawData) {
    final result = <Map<String, dynamic>>[];
    rawData.forEach((name, data) {
      if (data is Map && data['data'] is List) {
        result.add({
          'name': name,
          'list': (data['data'] as List).map((tag) => {
            'parent_id': tag['parent_id'],
            'parent_name': tag['pname'],
            'id': tag['id'],
            'name': tag['name'],
            'source': 'kg',
          }).toList(),
        });
      }
    });
    return result;
  }
}
