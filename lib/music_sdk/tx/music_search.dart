import 'dart:convert';
import '../../utils/http_client.dart';
import '../../utils/format_util.dart';
import '../../models/search_result.dart';

/// QQ音乐搜索 — 使用 c.y.qq.com 旧版 API（确认可用）
class TxMusicSearch {
  static const int limit = 50;

  /// 搜索音乐 — 使用旧版 c.y.qq.com API
  static Future<SearchResult> search(String keyword, {int page = 1, int? pageSize, int retryNum = 0}) async {
    if (retryNum > 3) throw Exception('搜索失败');
    final size = pageSize ?? limit;

    try {
      final resp = await HttpClient.get(
        'https://c.y.qq.com/soso/fcgi-bin/client_search_cp?ct=24&qqmusic_ver=1298&remoteplace=sizer.yqq.song_next&searchid=49252838123499591&t=0&aggr=1&cr=1&catZhida=1&lossless=0&flag_qc=0&p=$page&n=$size&w=${Uri.encodeComponent(keyword)}&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8&notice=0&platform=yqq&needNewCode=0',
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36',
        },
      );

      if (resp.statusCode != 200 || resp.jsonBody == null) {
        return search(keyword, page: page, pageSize: size, retryNum: retryNum + 1);
      }

      final json = resp.jsonBody;
      final code = json['code'];
      if (code != 0) {
        return search(keyword, page: page, pageSize: size, retryNum: retryNum + 1);
      }

      final songData = json['data']?['song'];
      if (songData == null) {
        return search(keyword, page: page, pageSize: size, retryNum: retryNum + 1);
      }

      final rawList = songData['list'] as List? ?? [];
      if (rawList.isEmpty) {
        return search(keyword, page: page, pageSize: size, retryNum: retryNum + 1);
      }

      final list = _handleResult(rawList);
      final total = songData['totalnum'] ?? 0;
      final allPage = (total / size).ceil();

      return SearchResult(
        list: list,
        allPage: allPage,
        limit: size,
        total: total,
        source: 'tx',
      );
    } catch (_) {
      return search(keyword, page: page, pageSize: size, retryNum: retryNum + 1);
    }
  }

  /// 处理搜索结果 — 旧版 API 响应格式
  static List<Map<String, dynamic>> _handleResult(List rawList) {
    final list = <Map<String, dynamic>>[];

    for (final item in rawList) {
      final types = <Map<String, dynamic>>[];
      final typesMap = <String, Map<String, dynamic>>{};

      if ((item['size128'] ?? 0) != 0) {
        final size = sizeFormate(item['size128']);
        types.add({'type': '128k', 'size': size});
        typesMap['128k'] = {'size': size};
      }
      if ((item['size320'] ?? 0) != 0) {
        final size = sizeFormate(item['size320']);
        types.add({'type': '320k', 'size': size});
        typesMap['320k'] = {'size': size};
      }
      if ((item['sizeflac'] ?? 0) != 0) {
        final size = sizeFormate(item['sizeflac']);
        types.add({'type': 'flac', 'size': size});
        typesMap['flac'] = {'size': size};
      }

      // 歌手
      final singers = item['singer'] as List? ?? [];
      final singer = singers.map((s) => s['name'] ?? '').where((n) => n.isNotEmpty).join('、');

      // 专辑
      final albumMid = item['albummid'] ?? '';
      final albumName = item['albumname'] ?? '';

      // 封面
      String img = '';
      if (albumMid.isEmpty || albumMid == '空') {
        if (singers.isNotEmpty) {
          img = 'https://y.gtimg.cn/music/photo_new/T001R500x500M000${singers[0]['mid']}.jpg';
        }
      } else {
        img = 'https://y.gtimg.cn/music/photo_new/T002R500x500M000$albumMid.jpg';
      }

      list.add({
        'singer': singer,
        'name': item['songname'] ?? item['name'] ?? '',
        'albumName': albumName,
        'albumId': albumMid,
        'source': 'tx',
        'interval': formatPlayTime(item['interval']),
        'songId': item['songid'],
        'albumMid': albumMid,
        'strMediaMid': item['strMediaMid'] ?? '',
        'songmid': item['songmid'] ?? '',
        'img': img,
        'types': types,
        '_types': typesMap,
        'typeUrl': {},
      });
    }
    return list;
  }
}
