import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../utils/http_client.dart';
import '../../utils/format_util.dart';
import '../../models/search_result.dart';

/// 咪咕音乐搜索 — 对齐 LX Music mg/musicSearch.js
/// API: https://jadeite.migu.cn/music_search/v3/search/searchAll
class MgMusicSearch {
  static const int _defaultLimit = 20;
  static const _signatureMd5 = '6cdc72a439cef99a3418d2a78aa28c73';
  static const _deviceId = '963B7AA0D21511ED807EE5846EC87D20';

  /// 创建签名 — 对齐 JS createSignature
  static Map<String, String> _createSignature(String time, String str) {
    final sign = md5.convert(utf8.encode(
      '$str$_signatureMd5''yyapp2d16148780a1dcc7408e06336b98cfd50$_deviceId$time'
    )).toString();
    return {'sign': sign, 'deviceId': _deviceId};
  }

  /// 搜索音乐
  /// 对齐 JS: search 内部有 ++retryNum > 3 重试机制
  static Future<SearchResult> search(String keyword, {int page = 1, int? pageSize, int retryNum = 0}) async {
    if (retryNum > 3) throw Exception('try max num');
    final size = pageSize ?? _defaultLimit;
    final time = DateTime.now().millisecondsSinceEpoch.toString();
    final signData = _createSignature(time, keyword);

    final resp = await HttpClient.get(
      'https://jadeite.migu.cn/music_search/v3/search/searchAll?isCorrect=0&isCopyright=1&searchSwitch=%7B%22song%22%3A1%2C%22album%22%3A0%2C%22singer%22%3A0%2C%22tagSong%22%3A1%2C%22mvSong%22%3A0%2C%22bestShow%22%3A1%2C%22songlist%22%3A0%2C%22lyricSong%22%3A0%7D&pageSize=$size&text=${Uri.encodeComponent(keyword)}&pageNo=$page&sort=0&sid=USS',
      headers: {
        'uiVersion': 'A_music_3.6.1',
        'deviceId': signData['deviceId']!,
        'timestamp': time,
        'sign': signData['sign']!,
        'channel': '0146921',
        'User-Agent': 'Mozilla/5.0 (Linux; U; Android 11.0.0; zh-cn; MI 11 Build/OPR1.170623.032) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30',
      },
    );

    // 对齐 JS: if (!result || result.code !== '000000') return Promise.reject(...)
    // 但 JS search 中没有内部重试（直接 reject），这里添加重试使更健壮
    if (resp.statusCode != 200 || resp.jsonBody == null) {
      return search(keyword, page: page, pageSize: size, retryNum: retryNum + 1);
    }

    final body = resp.jsonBody;
    if (body['code'] != '000000') {
      return search(keyword, page: page, pageSize: size, retryNum: retryNum + 1);
    }

    final songResultData = body['songResultData'] ?? {'resultList': [], 'totalCount': 0};
    final resultList = songResultData['resultList'] as List? ?? [];
    final list = _filterData(resultList);

    final total = int.tryParse(songResultData['totalCount']?.toString() ?? '0') ?? 0;
    final allPage = (total / size).ceil();

    return SearchResult(
      list: list,
      allPage: allPage,
      limit: size,
      total: total,
      source: 'mg',
    );
  }

  /// 过滤搜索结果 — 对齐 JS filterData
  /// 原始 JS: rawData.forEach(item => { item.forEach(data => { ... }) })
  /// 即 resultList 是二维数组，每个元素是一组歌曲
  static List<Map<String, dynamic>> _filterData(List rawData) {
    final list = <Map<String, dynamic>>[];
    final ids = <String>{};

    for (final itemGroup in rawData) {
      if (itemGroup is! List) continue;
      for (final data in itemGroup) {
        // 对齐 JS: if (!data.songId || !data.copyrightId || ids.has(data.copyrightId)) return
        if (data['songId'] == null || data['copyrightId'] == null) continue;
        if (ids.contains(data['copyrightId'])) continue;
        ids.add(data['copyrightId']);

        final types = <Map<String, String>>[];
        final typesMap = <String, Map<String, String>>{};
        final audioFormats = data['audioFormats'] as List? ?? [];

        for (final type in audioFormats) {
          // 对齐 JS: sizeFormate(type.asize ?? type.isize)
          switch (type['formatType']) {
            case 'PQ':
              final size = sizeFormate(type['asize'] ?? type['isize']);
              types.add({'type': '128k', 'size': size});
              typesMap['128k'] = {'size': size};
              break;
            case 'HQ':
              final size = sizeFormate(type['asize'] ?? type['isize']);
              types.add({'type': '320k', 'size': size});
              typesMap['320k'] = {'size': size};
              break;
            case 'SQ':
              final size = sizeFormate(type['asize'] ?? type['isize']);
              types.add({'type': 'flac', 'size': size});
              typesMap['flac'] = {'size': size};
              break;
            case 'ZQ24':
              final size = sizeFormate(type['asize'] ?? type['isize']);
              types.add({'type': 'flac24bit', 'size': size});
              typesMap['flac24bit'] = {'size': size};
              break;
          }
        }

        // 对齐 JS: img = data.img3 || data.img2 || data.img1 || null
        // 保留原始路径，不加 URL 前缀
        final img = data['img3'] ?? data['img2'] ?? data['img1'];

        list.add({
          'singer': formatSingerName(data['singerList']),
          'name': data['name'] ?? '',
          'albumName': data['album'],
          'albumId': data['albumId'],
          'songmid': data['songId'],
          'copyrightId': data['copyrightId'],
          'source': 'mg',
          'interval': formatPlayTime(data['duration']),
          'img': img,
          'lrc': null,
          'lrcUrl': data['lrcUrl'],
          'mrcUrl': data['mrcurl'],
          'trcUrl': data['trcUrl'],
          'types': types,
          '_types': typesMap,
          'typeUrl': {},
        });
      }
    }
    return list;
  }
}
