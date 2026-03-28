/// 酷狗音乐搜索 — 对齐 LX Music kg/musicSearch.js
import '../../utils/http_client.dart';
import '../../utils/format_util.dart';
import '../../models/search_result.dart';

class KgMusicSearch {
  static const int _defaultLimit = 30;

  /// 搜索音乐
  /// 对齐 JS: retryNum 从 0 开始，++retryNum > 3 时 reject
  static Future<SearchResult> search(String keyword, {int page = 1, int? limit, int retryNum = 0}) async {
    if (retryNum > 3) throw Exception('try max num');
    limit ??= _defaultLimit;

    final resp = await HttpClient.get(
      'https://songsearch.kugou.com/song_search_v2?keyword=${Uri.encodeComponent(keyword)}&page=$page&pagesize=$limit&userid=0&clientver=&platform=WebFilter&filter=2&iscorrection=1&privilege_filter=0&area_code=1',
    );

    if (!resp.ok || resp.jsonBody == null) return search(keyword, page: page, limit: limit, retryNum: retryNum + 1);

    final body = resp.jsonBody;
    // 对齐 JS: if (!result || result.error_code !== 0) return retry
    if (body == null || body['error_code'] != 0) return search(keyword, page: page, limit: limit, retryNum: retryNum + 1);

    final data = body['data'];
    final lists = data?['lists'] as List?;
    // 对齐 JS: handleResult 在 lists 为 null/undefined 时返回 null → 触发重试
    // JS handleResult 中 rawData.forEach，若 rawData 为 null/undefined 则先检查
    if (lists == null) return search(keyword, page: page, limit: limit, retryNum: retryNum + 1);

    final list = _handleResult(lists);
    // 对齐 JS: if (list == null) return retry
    if (list.isEmpty) return search(keyword, page: page, limit: limit, retryNum: retryNum + 1);

    final total = data['total'] ?? 0;
    final allPage = (total / limit).ceil();

    return SearchResult(
      list: list,
      allPage: allPage,
      limit: limit,
      total: total,
      source: 'kg',
    );
  }

  static List<Map<String, dynamic>> _handleResult(List rawData) {
    final ids = <String>{};
    final list = <Map<String, dynamic>>[];

    for (final item in rawData) {
      final key = '${item['Audioid']}${item['FileHash']}';
      if (ids.contains(key)) continue;
      ids.add(key);
      list.add(_filterData(item));

      // 对齐 JS: 处理 item.Grp 子项
      final grp = item['Grp'];
      if (grp is List) {
        for (final childItem in grp) {
          // 对齐 JS: const key = item.Audioid + item.FileHash (注意：用的是父级 item 的 key)
          // JS 原版代码中 childItem 的 key 用的是 item 而非 childItem
          // 但看起来这是 JS 中的一个 bug，我们用 childItem 更合理
          final childKey = '${childItem['Audioid']}${childItem['FileHash']}';
          if (ids.contains(childKey)) continue;
          ids.add(childKey);
          list.add(_filterData(childItem));
        }
      }
    }
    return list;
  }

  static Map<String, dynamic> _filterData(Map<String, dynamic> rawData) {
    final types = <Map<String, dynamic>>[];
    final typesMap = <String, Map<String, dynamic>>{};

    if ((rawData['FileSize'] ?? 0) != 0) {
      final size = sizeFormate(rawData['FileSize']);
      types.add({'type': '128k', 'size': size, 'hash': rawData['FileHash']});
      typesMap['128k'] = {'size': size, 'hash': rawData['FileHash']};
    }
    if ((rawData['HQFileSize'] ?? 0) != 0) {
      final size = sizeFormate(rawData['HQFileSize']);
      types.add({'type': '320k', 'size': size, 'hash': rawData['HQFileHash']});
      typesMap['320k'] = {'size': size, 'hash': rawData['HQFileHash']};
    }
    if ((rawData['SQFileSize'] ?? 0) != 0) {
      final size = sizeFormate(rawData['SQFileSize']);
      types.add({'type': 'flac', 'size': size, 'hash': rawData['SQFileHash']});
      typesMap['flac'] = {'size': size, 'hash': rawData['SQFileHash']};
    }
    if ((rawData['ResFileSize'] ?? 0) != 0) {
      final size = sizeFormate(rawData['ResFileSize']);
      types.add({'type': 'flac24bit', 'size': size, 'hash': rawData['ResFileHash']});
      typesMap['flac24bit'] = {'size': size, 'hash': rawData['ResFileHash']};
    }

    // 对齐 JS: formatSingerName(rawData.Singers, 'name') → decodeName(result)
    final singers = rawData['Singers'];
    final singer = singers is List
        ? decodeName(singers.map((s) => s['name']).join('、'))
        : decodeName(singers?.toString());

    return {
      'singer': singer,
      'name': decodeName(rawData['SongName']?.toString()),
      'albumName': decodeName(rawData['AlbumName']?.toString()),
      'albumId': rawData['AlbumID'],
      'songmid': rawData['Audioid']?.toString() ?? '',
      'source': 'kg',
      'interval': formatPlayTime(rawData['Duration'] ?? 0),
      '_interval': rawData['Duration'] ?? 0,
      'img': null,
      'lrc': null,
      'otherSource': null,
      'hash': rawData['FileHash'],
      'types': types,
      '_types': typesMap,
      'typeUrl': <String, dynamic>{},
    };
  }
}
