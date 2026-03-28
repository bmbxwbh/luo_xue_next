import '../../utils/http_client.dart';
import '../../utils/format_util.dart';
import '../../models/search_result.dart';

/// 网易云音乐搜索 — 使用 cloudsearch/pc API
/// eapi 接口需要特殊 cookie 且服务器在国内经常超时
class WyMusicSearch {
  static const int _defaultLimit = 30;

  /// 搜索音乐 — 使用 music.163.com/api/cloudsearch/pc
  static Future<SearchResult> search(String keyword, {int page = 1, int? pageSize, int retryNum = 0}) async {
    if (retryNum > 3) throw Exception('try max num');
    final size = pageSize ?? _defaultLimit;
    final offset = size * (page - 1);

    try {
      final resp = await HttpClient.postForm(
        'https://music.163.com/api/cloudsearch/pc',
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36',
          'Referer': 'https://music.163.com/',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          's': keyword,
          'offset': '$offset',
          'limit': '$size',
          'type': '1',
        },
      );

      if (resp.statusCode != 200 || resp.jsonBody == null) {
        return search(keyword, page: page, pageSize: size, retryNum: retryNum + 1);
      }

      final body = resp.jsonBody;
      if (body['code'] != 200) {
        return search(keyword, page: page, pageSize: size, retryNum: retryNum + 1);
      }

      final songs = body['result']?['songs'] as List? ?? [];
      if (songs.isEmpty) {
        return search(keyword, page: page, pageSize: size, retryNum: retryNum + 1);
      }

      final list = _handleResult(songs);
      final total = body['result']?['songCount'] ?? 0;
      final allPage = (total / size).ceil();

      return SearchResult(
        list: list,
        allPage: allPage,
        limit: size,
        total: total,
        source: 'wy',
      );
    } catch (_) {
      return search(keyword, page: page, pageSize: size, retryNum: retryNum + 1);
    }
  }

  /// 处理搜索结果 — 对齐原始 cloudsearch 响应格式
  static List<Map<String, dynamic>> _handleResult(List rawList) {
    return rawList.map<Map<String, dynamic>>((item) {
      final types = <Map<String, dynamic>>[];
      final typesMap = <String, Map<String, dynamic>>{};

      final privilege = item['privilege'] ?? {};
      final maxbr = privilege['maxbr'] ?? 0;

      // 音质判断 — 对齐洛雪原始逻辑
      if (privilege['maxBrLevel'] == 'hires') {
        final size = item['hr'] != null ? sizeFormate(item['hr']['size']) : null;
        types.add({'type': 'flac24bit', 'size': size});
        typesMap['flac24bit'] = {'size': size ?? ''};
      }
      if (maxbr >= 999000) {
        final size = item['sq'] != null ? sizeFormate(item['sq']['size']) : null;
        types.add({'type': 'flac', 'size': size});
        typesMap['flac'] = {'size': size ?? ''};
      }
      if (maxbr >= 320000) {
        final size = item['h'] != null ? sizeFormate(item['h']['size']) : null;
        types.add({'type': '320k', 'size': size});
        typesMap['320k'] = {'size': size ?? ''};
      }
      if (maxbr >= 128000) {
        final size = item['l'] != null ? sizeFormate(item['l']['size']) : null;
        types.add({'type': '128k', 'size': size});
        typesMap['128k'] = {'size': size ?? ''};
      }

      // 反转音质顺序
      final reversedTypes = types.reversed.toList();

      final ar = item['ar'] as List? ?? [];
      final al = item['al'] ?? {};

      return {
        'singer': ar.map((s) => s['name'] ?? '').where((n) => n.isNotEmpty).join('、'),
        'name': item['name'] ?? '',
        'albumName': al['name'] ?? '',
        'albumId': al['id'],
        'source': 'wy',
        'interval': formatPlayTime((item['dt'] ?? 0) / 1000),
        'songmid': item['id'],
        'img': al['picUrl'],
        'lrc': null,
        'types': reversedTypes,
        '_types': typesMap,
        'typeUrl': {},
      };
    }).where((m) => m.isNotEmpty).toList();
  }
}
