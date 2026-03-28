/// 酷我音乐搜索 — 对齐 LX Music kw/musicSearch.js
import '../../utils/http_client.dart';
import '../../utils/format_util.dart';
import '../../models/search_result.dart';

class KwMusicSearch {
  static const int _defaultLimit = 30;
  static final _mInfoRegExp = RegExp(r'level:(\w+),bitrate:(\d+),format:(\w+),size:([\w.]+)');

  /// 搜索音乐
  static Future<SearchResult> search(String keyword, {int page = 1, int? limit, int retryNum = 0}) async {
    if (retryNum > 2) throw Exception('try max num');
    limit ??= _defaultLimit;

    final resp = await HttpClient.get(
      'http://search.kuwo.cn/r.s?client=kt&all=${Uri.encodeComponent(keyword)}&pn=${page - 1}&rn=$limit&uid=794762570&ver=kwplayer_ar_9.2.2.1&vipver=1&show_copyright_off=1&newver=1&ft=music&cluster=0&strategy=2012&encoding=utf8&rformat=json&vermerge=1&mobi=1&issubtitle=1',
    );

    if (!resp.ok || resp.jsonBody == null) return search(keyword, page: page, limit: limit, retryNum: retryNum + 1);

    final result = resp.jsonBody;
    // 对齐 JS: if (!result || (result.TOTAL !== '0' && result.SHOW === '0')) return retry
    if (result == null || (result['TOTAL'] != '0' && result['SHOW'] == '0')) {
      return search(keyword, page: page, limit: limit, retryNum: retryNum + 1);
    }

    final list = _handleResult(result['abslist'] as List?);
    // 对齐 JS: if (list == null) return retry (N_MINFO 为 undefined 时返回 null)
    if (list == null) return search(keyword, page: page, limit: limit, retryNum: retryNum + 1);

    final total = int.tryParse(result['TOTAL']?.toString() ?? '0') ?? 0;
    final allPage = (total / limit).ceil();

    return SearchResult(
      list: list,
      allPage: allPage,
      limit: limit,
      total: total,
      source: 'kw',
    );
  }

  static List<Map<String, dynamic>>? _handleResult(List? rawData) {
    if (rawData == null) return [];
    final result = <Map<String, dynamic>>[];

    for (final info in rawData) {
      final musicrid = info['MUSICRID']?.toString() ?? '';
      final songId = musicrid.replaceFirst('MUSIC_', '');

      if (info['N_MINFO'] == null) {
        return null; // Signal retry — 对齐 JS handleResult 中 N_MINFO undefined 时返回 null
      }

      final types = <Map<String, dynamic>>[];
      final typesMap = <String, Map<String, dynamic>>{};

      final infoArr = (info['N_MINFO'] as String).split(';');
      for (final infoStr in infoArr) {
        final match = _mInfoRegExp.firstMatch(infoStr);
        if (match != null) {
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
      }
      // 对齐 JS: types.reverse() — 修正：必须赋值回 types
      final reversedTypes = types.reversed.toList();

      final duration = int.tryParse(info['DURATION']?.toString() ?? '0') ?? 0;

      // 对齐 JS: singer = formatSinger(decodeName(info.ARTIST))
      // formatSinger = rawData.replace(/&/g, '、'), 然后外层 decodeName 解码实体
      final rawArtist = info['ARTIST']?.toString() ?? '';
      final singer = decodeName(rawArtist.replaceAll('&', '、'));

      result.add({
        'name': decodeName(info['SONGNAME']?.toString()),
        'singer': singer,
        'source': 'kw',
        'songmid': songId,
        'albumId': decodeName(info['ALBUMID']?.toString()),
        'interval': duration > 0 ? formatPlayTime(duration) : '00:00',
        '_interval': duration,
        'albumName': info['ALBUM'] != null ? decodeName(info['ALBUM'].toString()) : '',
        'lrc': null,
        'img': null,
        'otherSource': null,
        'types': reversedTypes,
        '_types': typesMap,
        'typeUrl': <String, dynamic>{},
      });
    }
    return result;
  }
}
