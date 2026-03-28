import '../../utils/http_client.dart';
import '../../utils/format_util.dart';

/// 咪咕音乐歌单 — 对齐 LX Music mg/songList.js
class MgSongList {
  static const int limitList = 30;
  static const int limitSong = 30;
  static const String successCode = '000000';

  static const Map<String, String> defaultHeaders = {
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1',
    'Referer': 'https://m.music.migu.cn/',
  };

  /// 排序列表
  static const List<Map<String, dynamic>> sortList = [
    {'name': '推荐', 'id': '15127315', 'tid': 'recommend'},
  ];

  /// 获取歌单推荐列表
  static Future<Map<String, dynamic>> getList(String sortId, {String? tagId, int page = 1}) async {
    String url;
    if (tagId == null) {
      url = 'https://app.c.nf.migu.cn/pc/bmw/page-data/playlist-square-recommend/v1.0?templateVersion=2&pageNo=$page';
    } else {
      url = 'https://app.c.nf.migu.cn/pc/v1.0/template/musiclistplaza-listbytag/release?pageNumber=$page&templateVersion=2&tagId=$tagId';
    }

    final resp = await HttpClient.get(url, headers: defaultHeaders);

    if (resp.statusCode != 200 || resp.jsonBody == null) {
      throw Exception('获取咪咕歌单列表失败');
    }

    final body = resp.jsonBody;
    if (body['code'] != successCode) {
      throw Exception('咪咕歌单API错误');
    }

    final data = body['data'] ?? {};
    List<Map<String, dynamic>> list;
    if (data['contents'] != null) {
      list = _filterList2(data['contents']);
    } else {
      list = _filterList((data['contentItemList'] as List?)?[1]?['itemList'] ?? []);
    }

    return {
      'list': list,
      'total': 99999,
      'page': page,
      'limit': limitList,
      'source': 'mg',
    };
  }

  /// 获取歌单详情
  /// API: https://app.c.nf.migu.cn/MIGUM3.0/resource/playlist/song/v2.0
  static Future<Map<String, dynamic>> getListDetail(String id) async {
    // 获取歌曲列表
    final listResp = await HttpClient.get(
      'https://app.c.nf.migu.cn/MIGUM3.0/resource/playlist/song/v2.0?pageNo=1&pageSize=$limitSong&playlistId=$id',
      headers: defaultHeaders,
    );

    if (listResp.statusCode != 200 || listResp.jsonBody == null) {
      throw Exception('获取咪咕歌单详情失败');
    }

    final listBody = listResp.jsonBody;
    if (listBody['code'] != successCode) {
      throw Exception('咪咕歌单详情API错误');
    }

    final songList = listBody['data']?['songList'] as List? ?? [];
    final list = _filterMusicInfoListV5(songList);

    // 获取歌单信息
    Map<String, dynamic> info = {};
    try {
      final infoResp = await HttpClient.get(
        'https://c.musicapp.migu.cn/MIGUM3.0/resource/playlist/v2.0?playlistId=$id',
        headers: defaultHeaders,
      );
      if (infoResp.statusCode == 200 && infoResp.jsonBody?['code'] == successCode) {
        final data = infoResp.jsonBody['data'];
        info = {
          'name': data['title'],
          'img': data['imgItem']?['img'],
          'desc': data['summary'],
          'author': data['ownerName'],
          'play_count': formatPlayCount(data['opNumItem']?['playNum']),
        };
      }
    } catch (_) {}

    return {
      'list': list,
      'page': 1,
      'limit': limitSong,
      'total': listBody['data']?['totalCount'] ?? list.length,
      'source': 'mg',
      'info': info,
    };
  }

  /// 搜索歌单
  /// API: https://jadeite.migu.cn/music_search/v3/search/searchAll
  static Future<Map<String, dynamic>> search(String text, {int page = 1, int limit = 20}) async {
    final timeStr = DateTime.now().millisecondsSinceEpoch.toString();
    final signResult = _createSignature(timeStr, text);

    final resp = await HttpClient.get(
      'https://jadeite.migu.cn/music_search/v3/search/searchAll?isCorrect=1&isCopyright=1&searchSwitch=%7B%22song%22%3A0%2C%22album%22%3A0%2C%22singer%22%3A0%2C%22tagSong%22%3A0%2C%22mvSong%22%3A0%2C%22bestShow%22%3A0%2C%22songlist%22%3A1%2C%22lyricSong%22%3A0%7D&pageSize=$limit&text=${Uri.encodeComponent(text)}&pageNo=$page&sort=0&sid=USS',
      headers: {
        'uiVersion': 'A_music_3.6.1',
        'deviceId': signResult['deviceId']!,
        'timestamp': timeStr,
        'sign': signResult['sign']!,
        'channel': '0146921',
        'User-Agent': 'Mozilla/5.0 (Linux; U; Android 11.0.0; zh-cn; MI 11 Build/OPR1.170623.032) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30',
      },
    );

    if (resp.statusCode != 200 || resp.jsonBody == null) {
      throw Exception('搜索咪咕歌单失败');
    }

    final body = resp.jsonBody;
    if (body['songListResultData'] == null) {
      throw Exception('咪咕歌单搜索无结果');
    }

    final result = body['songListResultData']['result'] as List? ?? [];
    final list = _filterSongListResult(result);

    return {
      'list': list,
      'limit': limit,
      'total': int.tryParse(body['songListResultData']['totalCount']?.toString() ?? '0') ?? 0,
      'source': 'mg',
    };
  }

  /// 创建签名
  static Map<String, String> _createSignature(String time, String str) {
    // 简化签名
    return {'sign': '', 'deviceId': '963B7AA0D21511ED807EE5846EC87D20'};
  }

  /// 过滤歌单列表 (推荐)
  static List<Map<String, dynamic>> _filterList(List rawData) {
    return rawData.map<Map<String, dynamic>>((item) {
      final barList = item['barList'] as List? ?? [];
      final logEvent = item['logEvent'] ?? {};
      return {
        'play_count': barList.isNotEmpty ? barList[0]['title'] : '',
        'id': logEvent['contentId']?.toString() ?? '',
        'author': '',
        'name': item['title'] ?? '',
        'img': item['imageUrl'],
        'desc': '',
        'source': 'mg',
      };
    }).toList();
  }

  /// 过滤歌单列表 (分类)
  static List<Map<String, dynamic>> _filterList2(List listData) {
    final list = <Map<String, dynamic>>[];
    final ids = <String>{};

    void parse(dynamic item) {
      if (item is! Map) return;
      if (item['contents'] != null) {
        for (final c in item['contents']) {
          parse(c);
        }
      } else if (item['resType'] == '2021' && !ids.contains(item['resId'])) {
        ids.add(item['resId'].toString());
        list.add({
          'id': item['resId']?.toString() ?? '',
          'author': '',
          'name': item['txt'] ?? '',
          'img': item['img'],
          'desc': item['txt2'] ?? '',
          'source': 'mg',
        });
      }
    }

    for (final item in listData) {
      parse(item);
    }
    return list;
  }

  /// 过滤歌曲列表 (V5 API)
  static List<Map<String, dynamic>> _filterMusicInfoListV5(List rawList) {
    final list = <Map<String, dynamic>>[];
    final ids = <String>{};

    for (final item in rawList) {
      if (item['songId'] == null || ids.contains(item['songId'])) continue;
      ids.add(item['songId']);

      final types = <Map<String, String>>[];
      final typesMap = <String, Map<String, String>>{};
      final audioFormats = item['audioFormats'] as List? ?? [];

      for (final type in audioFormats) {
        switch (type['formatType']) {
          case 'PQ':
            final size = sizeFormate(type['size'] ?? type['androidSize']);
            types.add({'type': '128k', 'size': size});
            typesMap['128k'] = {'size': size};
            break;
          case 'HQ':
            final size = sizeFormate(type['size'] ?? type['androidSize']);
            types.add({'type': '320k', 'size': size});
            typesMap['320k'] = {'size': size};
            break;
          case 'SQ':
            final size = sizeFormate(type['size'] ?? type['androidSize']);
            types.add({'type': 'flac', 'size': size});
            typesMap['flac'] = {'size': size};
            break;
          case 'ZQ':
            final size = sizeFormate(type['size'] ?? type['androidSize']);
            types.add({'type': 'flac24bit', 'size': size});
            typesMap['flac24bit'] = {'size': size};
            break;
        }
      }

      list.add({
        'singer': formatSingerName(item['singerList']),
        'name': item['songName'],
        'albumName': item['album'],
        'albumId': item['albumId'],
        'songmid': item['songId'],
        'copyrightId': item['copyrightId'],
        'source': 'mg',
        'interval': formatPlayTime(item['duration']),
        'img': item['img3'] ?? item['img2'] ?? item['img1'],
        'lrc': null,
        'lrcUrl': item['lrcUrl'],
        'mrcUrl': item['mrcUrl'],
        'trcUrl': item['trcUrl'],
        'otherSource': null,
        'types': types,
        '_types': typesMap,
        'typeUrl': {},
      });
    }
    return list;
  }

  /// 过滤搜索歌单结果
  static List<Map<String, dynamic>> _filterSongListResult(List raw) {
    final list = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item['id'] == null) continue;
      final playCount = int.tryParse(item['playNum']?.toString() ?? '0') ?? 0;
      list.add({
        'play_count': playCount,
        'id': item['id'].toString(),
        'author': item['userName'],
        'name': item['name'],
        'img': item['musicListPicUrl'],
        'total': item['musicNum'],
        'source': 'mg',
      });
    }
    return list;
  }
}
