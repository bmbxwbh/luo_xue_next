/// 酷我歌单 — 对齐 LX Music kw/songList.js
import 'dart:math';
import '../../utils/http_client.dart';
import '../../utils/format_util.dart';

class KwSongList {
  static const int limitList = 36;
  static const int limitSong = 1000;
  static const int successCode = 200;
  static final _mInfoRegExp = RegExp(r'level:(\w+),bitrate:(\d+),format:(\w+),size:([\w.]+)');

  /// 排序列表
  static const sortList = [
    {'name': '最新', 'tid': 'new', 'id': 'new'},
    {'name': '最热', 'tid': 'hot', 'id': 'hot'},
  ];

  static const _tagsUrl = 'http://wapi.kuwo.cn/api/pc/classify/playlist/getTagList?cmd=rcm_keyword_playlist&user=0&prod=kwplayer_pc_9.0.5.0&vipver=9.0.5.0&source=kwplayer_pc_9.0.5.0&loginUid=0&loginSid=0&appUid=76039576';
  static const _hotTagUrl = 'http://wapi.kuwo.cn/api/pc/classify/playlist/getRcmTagList?loginUid=0&loginSid=0&appUid=76039576';

  static String _getListUrl({String? sortId, String? id, String? type, required int page}) {
    if (id == null || id.isEmpty) {
      return 'http://wapi.kuwo.cn/api/pc/classify/playlist/getRcmPlayList?loginUid=0&loginSid=0&appUid=76039576&pn=$page&rn=$limitList&order=$sortId';
    }
    switch (type) {
      case '10000':
        return 'http://wapi.kuwo.cn/api/pc/classify/playlist/getTagPlayList?loginUid=0&loginSid=0&appUid=76039576&pn=$page&id=$id&rn=$limitList';
      case '43':
        return 'http://mobileinterfaces.kuwo.cn/er.s?type=get_pc_qz_data&f=web&id=$id&prod=pc';
      default:
        return 'http://wapi.kuwo.cn/api/pc/classify/playlist/getTagPlayList?loginUid=0&loginSid=0&appUid=76039576&pn=$page&id=$id&rn=$limitList';
    }
  }

  static String _getListDetailUrl(String id, int page) {
    return 'http://nplserver.kuwo.cn/pl.svc?op=getlistinfo&pid=$id&pn=${page - 1}&rn=$limitSong&encode=utf8&keyset=pl2012&identity=kuwo&pcmp4=1&vipver=MUSIC_9.0.5.0_W1&newver=1';
  }

  /// 生成随机 reqId (对齐 kw/songList.js getReqId)
  static String _getReqId() {
    final rand = Random.secure();
    String t() {
      final v = (65536 * (1 + rand.nextDouble())).toInt();
      return v.toRadixString(16).substring(1);
    }
    return '${t()}${t()}${t()}${t()}${t()}${t()}${t()}${t()}';
  }

  /// 格式化播放次数
  static String _formatPlayCount(dynamic num) {
    final n = num is int ? num : int.tryParse(num.toString()) ?? 0;
    if (n > 100000000) return '${(n ~/ 10000000) / 10}亿';
    if (n > 10000) return '${(n ~/ 1000) / 10}万';
    return n.toString();
  }

  /// 获取标签
  static Future<Map<String, dynamic>> getTags() async {
    final results = await Future.wait([_getTag(), _getHotTag()]);
    return {'tags': results[0], 'hotTag': results[1], 'source': 'kw'};
  }

  static Future<List<Map<String, dynamic>>> _getTag({int retryNum = 0}) async {
    if (retryNum > 2) throw Exception('try max num');
    try {
      final resp = await HttpClient.get(_tagsUrl);
      final body = resp.jsonBody;
      if (body == null || body['code'] != successCode) return _getTag(retryNum: retryNum + 1);
      return _filterTagInfo(body['data'] as List);
    } catch (_) {
      return _getTag(retryNum: retryNum + 1);
    }
  }

  static Future<List<Map<String, dynamic>>> _getHotTag({int retryNum = 0}) async {
    if (retryNum > 2) throw Exception('try max num');
    try {
      final resp = await HttpClient.get(_hotTagUrl);
      final body = resp.jsonBody;
      if (body == null || body['code'] != successCode) return _getHotTag(retryNum: retryNum + 1);
      return _filterInfoHotTag(body['data'][0]['data'] as List);
    } catch (_) {
      return _getHotTag(retryNum: retryNum + 1);
    }
  }

  /// 获取列表数据
  static Future<Map<String, dynamic>> getList(String sortId, String? tagId, int page, {int retryNum = 0}) async {
    if (retryNum > 2) throw Exception('try max num');
    try {
      String? id;
      String? type;
      if (tagId != null && tagId.isNotEmpty) {
        final arr = tagId.split('-');
        id = arr[0];
        type = arr.length > 1 ? arr[1] : null;
      }

      final resp = await HttpClient.get(_getListUrl(sortId: sortId, id: id, type: type, page: page));
      final body = resp.jsonBody;

      if (id == null || type == '10000') {
        // 标准 JSON 响应
        if (body == null || body is! Map || body['code'] != successCode) {
          return getList(sortId, tagId, page, retryNum: retryNum + 1);
        }
        final data = body['data'];
        return {
          'list': _filterList(data['data'] as List),
          'total': data['total'],
          'page': data['pn'],
          'limit': data['rn'],
          'source': 'kw',
        };
      } else {
        // 其他类型返回数组
        if (body == null || body is! List || (body as List).isEmpty) {
          return getList(sortId, tagId, page, retryNum: retryNum + 1);
        }
        return {
          'list': _filterList2(body as List),
          'total': 1000,
          'page': page,
          'limit': 1000,
          'source': 'kw',
        };
      }
    } catch (_) {
      return getList(sortId, tagId, page, retryNum: retryNum + 1);
    }
  }

  /// 获取歌单详情 — 对齐 kw/songList.js getListDetail
  static Future<Map<String, dynamic>> getListDetail(String id, int page, {int retryNum = 0}) async {
    if (retryNum > 2) throw Exception('try max num');

    // 处理 bodian (BD) 格式的 ID
    if (id.contains('/bodian/')) {
      return _getListDetailMusicListByBD(id, page);
    }

    // 处理 URL 格式
    if (RegExp(r'[?&:/]').hasMatch(id)) {
      final match = RegExp(r'^.+/playlist(?:_detail)?/(\d+)(?:\?.*|&.*$|#.*$|$)').firstMatch(id);
      if (match != null) id = match.group(1)!;
    } else if (id.startsWith('digest-')) {
      final parts = id.split('__');
      final digest = parts[0].replaceFirst('digest-', '');
      if (parts.length > 1) id = parts[1];
      switch (digest) {
        case '13':
          // album - 暂不实现
          break;
        case '5':
          return _getListDetailDigest5(id, page, retryNum);
        case '8':
        default:
          break;
      }
    }

    return _getListDetailDigest8(id, page, retryNum);
  }

  /// 获取详情 - Digest 8 (旧 API)
  static Future<Map<String, dynamic>> _getListDetailDigest8(String id, int page, int retryNum) async {
    if (retryNum > 2) throw Exception('try max num');
    try {
      final resp = await HttpClient.get(
        _getListDetailUrl(id, page),
        headers: {
          'Referer': 'http://www.kuwo.cn/playlist_detail/$id',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36',
        },
      );
      final body = resp.jsonBody;
      if (body == null || body['result'] != 'ok') {
        return _getListDetailDigest8(id, page, retryNum + 1);
      }
      return {
        'list': _filterListDetail(body['musiclist'] as List),
        'page': page,
        'limit': body['rn'],
        'total': body['total'],
        'source': 'kw',
        'info': {
          'name': body['title'],
          'img': body['pic'],
          'desc': body['info'],
          'author': body['uname'],
          'play_count': _formatPlayCount(body['playnum']),
        },
      };
    } catch (_) {
      return _getListDetailDigest8(id, page, retryNum + 1);
    }
  }

  /// 获取详情 - Digest 5
  static Future<Map<String, dynamic>> _getListDetailDigest5(String id, int page, int retryNum) async {
    if (retryNum > 2) throw Exception('try max num');
    try {
      // 先获取真实 ID
      final infoResp = await HttpClient.get(
        'http://qukudata.kuwo.cn/q.k?op=query&cont=ninfo&node=$id&pn=0&rn=1&fmt=json&src=mbox&level=2',
      );
      if (infoResp.statusCode != 200) return _getListDetailDigest5(id, page, retryNum + 1);
      final infoBody = infoResp.jsonBody;
      if (infoBody == null || infoBody['child'] == null) return _getListDetailDigest5(id, page, retryNum + 1);
      final children = infoBody['child'] as List;
      if (children.isEmpty) return _getListDetailDigest5(id, page, retryNum + 1);
      final realId = children[0]['sourceid'];
      if (realId == null) return _getListDetailDigest5(id, page, retryNum + 1);

      // 用真实 ID 获取详情
      final resp = await HttpClient.get(
        'http://nplserver.kuwo.cn/pl.svc?op=getlistinfo&pid=$realId&pn=${page - 1}&rn=$limitSong&encode=utf-8&keyset=pl2012&identity=kuwo&pcmp4=1',
      );
      final body = resp.jsonBody;
      if (body == null || body['result'] != 'ok') return _getListDetailDigest5(id, page, retryNum + 1);
      return {
        'list': _filterListDetail(body['musiclist'] as List),
        'page': page,
        'limit': body['rn'],
        'total': body['total'],
        'source': 'kw',
        'info': {
          'name': body['title'],
          'img': body['pic'],
          'desc': body['info'],
          'author': body['uname'],
          'play_count': _formatPlayCount(body['playnum']),
        },
      };
    } catch (_) {
      return _getListDetailDigest5(id, page, retryNum + 1);
    }
  }

  /// 获取详情 - BD 格式 (新 API)
  static Future<Map<String, dynamic>> _getListDetailMusicListByBD(String id, int page) async {
    final uidMatch = RegExp(r'uid=(\d+)').firstMatch(id);
    final listIdMatch = RegExp(r'playlistId=(\d+)').firstMatch(id);
    final sourceMatch = RegExp(r'source=(\d+)').firstMatch(id);

    final uid = uidMatch?.group(1);
    final listId = listIdMatch?.group(1);
    final source = sourceMatch?.group(1);

    if (listId == null) throw Exception('failed');

    final bdHeaders = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36',
      'plat': 'h5',
    };

    // 并行获取歌曲列表和歌单信息
    final futures = <Future>[_getListDetailBDList(listId, source ?? '4', page, bdHeaders)];
    if (source == '4') {
      futures.add(_getListDetailBDListInfo(listId, source!, bdHeaders));
    } else if (source == '5') {
      futures.add(_getListDetailBDUserPub(uid ?? listId, bdHeaders));
    }

    final results = await Future.wait(futures);
    final listData = results[0] as Map<String, dynamic>;
    final info = results.length > 1 ? results[1] as Map<String, dynamic>? : null;

    listData['info'] = info ??
        {'name': '', 'img': '', 'desc': '', 'author': '', 'play_count': ''};
    return listData;
  }

  /// BD API: 获取歌曲列表
  static Future<Map<String, dynamic>> _getListDetailBDList(
    String listId, String source, int page, Map<String, String> headers,
    {int retryNum = 0}) async {
    if (retryNum > 2) throw Exception('try max num');
    try {
      final reqId = _getReqId();
      final resp = await HttpClient.get(
        'https://bd-api.kuwo.cn/api/service/playlist/$listId/musicList?reqId=$reqId&source=$source&pn=$page&rn=$limitSong',
        headers: headers,
      );
      final body = resp.jsonBody;
      if (body == null || body['code'] != 200) {
        return _getListDetailBDList(listId, source, page, headers, retryNum: retryNum + 1);
      }
      return {
        'list': _filterBDListDetail(body['data']['list'] as List),
        'page': page,
        'limit': body['data']['pageSize'],
        'total': body['data']['total'],
        'source': 'kw',
      };
    } catch (_) {
      if (retryNum > 2) throw Exception('try max num');
      return _getListDetailBDList(listId, source, page, headers, retryNum: retryNum + 1);
    }
  }

  /// BD API: 获取歌单信息
  static Future<Map<String, dynamic>?> _getListDetailBDListInfo(
    String listId, String source, Map<String, String> headers) async {
    try {
      final reqId = _getReqId();
      final resp = await HttpClient.get(
        'https://bd-api.kuwo.cn/api/service/playlist/info/$listId?reqId=$reqId&source=$source',
        headers: headers,
      );
      final body = resp.jsonBody;
      if (body == null || body['code'] != 200) return null;
      return {
        'name': body['data']['name'],
        'img': body['data']['pic'],
        'desc': body['data']['description'],
        'author': body['data']['creatorName'],
        'play_count': body['data']['playNum'],
      };
    } catch (_) {
      return null;
    }
  }

  /// BD API: 获取用户信息
  static Future<Map<String, dynamic>?> _getListDetailBDUserPub(
    String userId, Map<String, String> headers) async {
    try {
      final reqId = _getReqId();
      final resp = await HttpClient.get(
        'https://bd-api.kuwo.cn/api/ucenter/users/pub/$userId?reqId=$reqId',
        headers: headers,
      );
      final body = resp.jsonBody;
      if (body == null || body['code'] != 200) return null;
      final userInfo = body['data']['userInfo'];
      return {
        'name': '${userInfo['nickname']}喜欢的音乐',
        'img': userInfo['headImg'],
        'desc': '',
        'author': userInfo['nickname'],
        'play_count': '',
      };
    } catch (_) {
      return null;
    }
  }

  /// 过滤 BD 歌曲详情
  static List<Map<String, dynamic>> _filterBDListDetail(List rawData) {
    return rawData.map((item) {
      final types = <Map<String, dynamic>>[];
      final typesMap = <String, Map<String, dynamic>>{};
      final audios = item['audios'] as List? ?? [];

      for (final info in audios) {
        final size = (info['size']?.toString() ?? '').toUpperCase();
        switch (info['bitrate']?.toString()) {
          case '4000':
            types.add({'type': 'flac24bit', 'size': size});
            typesMap['flac24bit'] = {'size': size};
            break;
          case '2000':
            types.add({'type': 'flac', 'size': size});
            typesMap['flac'] = {'size': size};
            break;
          case '320':
            types.add({'type': '320k', 'size': size});
            typesMap['320k'] = {'size': size};
            break;
          case '128':
            types.add({'type': '128k', 'size': size});
            typesMap['128k'] = {'size': size};
            break;
        }
      }

      return {
        'singer': (item['artists'] as List? ?? []).map((s) => s['name']).join('、'),
        'name': item['name'],
        'albumName': item['album'],
        'albumId': item['albumId'],
        'songmid': item['id']?.toString() ?? '',
        'source': 'kw',
        'interval': formatPlayTime(item['duration']),
        'img': item['albumPic'],
        'releaseDate': item['releaseDate'],
        'lrc': null,
        'otherSource': null,
        'types': types.reversed.toList(),
        '_types': typesMap,
        'typeUrl': <String, dynamic>{},
      };
    }).toList();
  }

  /// 获取详情页 URL
  static String getDetailPageUrl(String id) {
    if (RegExp(r'[?&:/]').hasMatch(id)) {
      final match = RegExp(r'^.+/playlist(?:_detail)?/(\d+)(?:\?.*|&.*$|#.*$|$)').firstMatch(id);
      if (match != null) id = match.group(1)!;
    } else if (id.startsWith('digest-')) {
      final parts = id.split('__');
      if (parts.length > 1) id = parts[1];
    }
    return 'http://www.kuwo.cn/playlist_detail/$id';
  }

  /// 搜索歌单
  static Future<Map<String, dynamic>> search(String text, int page, {int limit = 20}) async {
    final resp = await HttpClient.get(
      'http://search.kuwo.cn/r.s?all=${Uri.encodeComponent(text)}&pn=${page - 1}&rn=$limit&rformat=json&encoding=utf8&ver=mbox&vipver=MUSIC_8.7.7.0_BCS37&plat=pc&devid=28156413&ft=playlist&pay=0&needliveshow=0',
    );
    var body = resp.jsonBody;
    if (body is String) {
      body = _objStr2JSON(body as String);
    }
    return {
      'list': (body['abslist'] as List).map((item) => {
        'play_count': _formatPlayCount(item['playcnt']),
        'id': item['playlistid'],
        'author': decodeName(item['nickname']?.toString()),
        'name': decodeName(item['name']?.toString()),
        'total': item['songnum'],
        'img': item['pic'],
        'desc': decodeName(item['intro']?.toString()),
        'source': 'kw',
      }).toList(),
      'limit': limit,
      'total': int.tryParse(body['TOTAL']?.toString() ?? '0') ?? 0,
      'source': 'kw',
    };
  }

  static dynamic _objStr2JSON(String str) {
    // 对齐 kw/util.js objStr2JSON
    final cleaned = str.replaceAllMapped(
      RegExp(r"('(?=(,\s*')))|('(?=:))|((?<=([:,]\s*))')|((?<={)')|('(?=}))"),
      (match) => '"',
    );
    try {
      return Uri.decodeComponent(cleaned);
    } catch (_) {
      return cleaned;
    }
  }

  static List<Map<String, dynamic>> _filterList(List rawData) {
    return rawData.map((item) => {
      'play_count': _formatPlayCount(item['listencnt']),
      'id': 'digest-${item['digest']}__${item['id']}',
      'author': item['uname'],
      'name': item['name'],
      'total': item['total'],
      'img': item['img'],
      'grade': (item['favorcnt'] ?? 0) / 10,
      'desc': item['desc'],
      'source': 'kw',
    }).toList();
  }

  static List<Map<String, dynamic>> _filterList2(List rawData) {
    final list = <Map<String, dynamic>>[];
    for (final item in rawData) {
      if (item['label'] == null) continue;
      if (item['list'] is List) {
        for (final subItem in item['list']) {
          list.add({
            'play_count': subItem['play_count'] != null ? _formatPlayCount(subItem['listencnt']) : null,
            'id': 'digest-${subItem['digest']}__${subItem['id']}',
            'author': subItem['uname'],
            'name': subItem['name'],
            'total': subItem['total'],
            'img': subItem['img'],
            'grade': subItem['favorcnt'] != null ? subItem['favorcnt'] / 10 : null,
            'desc': subItem['desc'],
            'source': 'kw',
          });
        }
      }
    }
    return list;
  }

  static List<Map<String, dynamic>> _filterListDetail(List rawData) {
    return rawData.map((item) {
      final types = <Map<String, dynamic>>[];
      final typesMap = <String, Map<String, dynamic>>{};

      final minfo = item['N_MINFO']?.toString() ?? '';
      for (final info in minfo.split(';')) {
        final match = _mInfoRegExp.firstMatch(info);
        if (match == null) continue;
        switch (match.group(2)) {
          case '4000':
            types.add({'type': 'flac24bit', 'size': match.group(4)});
            typesMap['flac24bit'] = {'size': match.group(4)!.toUpperCase()};
            break;
          case '2000':
            types.add({'type': 'flac', 'size': match.group(4)});
            typesMap['flac'] = {'size': match.group(4)!.toUpperCase()};
            break;
          case '320':
            types.add({'type': '320k', 'size': match.group(4)});
            typesMap['320k'] = {'size': match.group(4)!.toUpperCase()};
            break;
          case '128':
            types.add({'type': '128k', 'size': match.group(4)});
            typesMap['128k'] = {'size': match.group(4)!.toUpperCase()};
            break;
        }
      }

      return {
        'singer': (item['artist']?.toString() ?? '').replaceAll('&', '、'),
        'name': decodeName(item['name']?.toString()),
        'albumName': decodeName(item['album']?.toString()),
        'albumId': item['albumid'],
        'songmid': item['id']?.toString() ?? '',
        'source': 'kw',
        'interval': formatPlayTime(int.tryParse(item['duration']?.toString() ?? '0') ?? 0),
        'img': null,
        'lrc': null,
        'otherSource': null,
        'types': types.reversed.toList(),
        '_types': typesMap,
        'typeUrl': <String, dynamic>{},
      };
    }).toList();
  }

  static List<Map<String, dynamic>> _filterTagInfo(List rawList) {
    return rawList.map((type) => {
      'name': type['name'],
      'list': (type['data'] as List).map((item) => {
        'parent_id': type['id'],
        'parent_name': type['name'],
        'id': '${item['id']}-${item['digest']}',
        'name': item['name'],
        'source': 'kw',
      }).toList(),
    }).toList();
  }

  static List<Map<String, dynamic>> _filterInfoHotTag(List rawList) {
    return rawList.map((item) => {
      'id': '${item['id']}-${item['digest']}',
      'name': item['name'],
      'source': 'kw',
    }).toList();
  }
}
