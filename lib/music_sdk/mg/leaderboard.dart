import '../../utils/http_client.dart';
import '../../utils/format_util.dart';

/// 咪咕音乐排行榜 — 对齐 LX Music mg/leaderboard.js
/// API: https://app.c.nf.migu.cn/MIGUM2.0/v1.0/content/querycontentbyId.do
class MgLeaderboard {
  static const String successCode = '000000';

  /// 预设榜单列表
  static const List<Map<String, dynamic>> boardList = [
    {'id': 'mg__27553319', 'name': '新歌榜', 'bangid': '27553319', 'source': 'mg'},
    {'id': 'mg__27186466', 'name': '热歌榜', 'bangid': '27186466', 'source': 'mg'},
    {'id': 'mg__27553408', 'name': '原创榜', 'bangid': '27553408', 'source': 'mg'},
    {'id': 'mg__75959118', 'name': '音乐风向榜', 'bangid': '75959118', 'source': 'mg'},
    {'id': 'mg__76557036', 'name': '彩铃分贝榜', 'bangid': '76557036', 'source': 'mg'},
    {'id': 'mg__76557745', 'name': '会员臻爱榜', 'bangid': '76557745', 'source': 'mg'},
    {'id': 'mg__23189800', 'name': '港台榜', 'bangid': '23189800', 'source': 'mg'},
    {'id': 'mg__23189399', 'name': '内地榜', 'bangid': '23189399', 'source': 'mg'},
    {'id': 'mg__19190036', 'name': '欧美榜', 'bangid': '19190036', 'source': 'mg'},
    {'id': 'mg__83176390', 'name': '国风金曲榜', 'bangid': '83176390', 'source': 'mg'},
  ];

  /// 获取榜单列表
  static Future<List<Map<String, dynamic>>> getBoards() async {
    return boardList;
  }

  /// 获取榜单详情
  /// API: https://app.c.nf.migu.cn/MIGUM2.0/v1.0/content/querycontentbyId.do
  static Future<Map<String, dynamic>> getList(String bangId) async {
    final resp = await HttpClient.get(
      'https://app.c.nf.migu.cn/MIGUM2.0/v1.0/content/querycontentbyId.do?columnId=$bangId&needAll=0',
    );

    if (resp.statusCode != 200 || resp.jsonBody == null) {
      throw Exception('获取咪咕排行榜失败');
    }

    final body = resp.jsonBody;
    if (body['code'] != successCode) {
      throw Exception('咪咕排行榜API错误');
    }

    final contents = body['columnInfo']?['contents'] as List? ?? [];
    final rawList = contents.map((m) => m['objectInfo']).where((m) => m != null).toList();
    final list = _filterMusicInfoList(rawList);

    return {
      'total': list.length,
      'list': list,
      'limit': 200,
      'page': 1,
      'source': 'mg',
    };
  }

  /// 过滤音乐信息列表 (对齐 LX Music mg/musicInfo.js filterMusicInfoList)
  static List<Map<String, dynamic>> _filterMusicInfoList(List rawList) {
    final list = <Map<String, dynamic>>[];
    final ids = <String>{};

    for (final item in rawList) {
      if (item['songId'] == null || ids.contains(item['songId'])) continue;
      ids.add(item['songId']);

      final types = <Map<String, String>>[];
      final typesMap = <String, Map<String, String>>{};
      final newRateFormats = item['newRateFormats'] as List? ?? [];

      for (final type in newRateFormats) {
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

      // 时长解析
      final lengthStr = item['length']?.toString() ?? '';
      final match = RegExp(r'(\d\d:\d\d)$').firstMatch(lengthStr);
      final interval = match?.group(1);

      // 封面图
      final albumImgs = item['albumImgs'] as List? ?? [];
      String? img;
      if (albumImgs.isNotEmpty) {
        img = albumImgs[0]['img'];
      }

      list.add({
        'singer': formatSingerName(item['artists']),
        'name': item['songName'],
        'albumName': item['album'],
        'albumId': item['albumId'],
        'songmid': item['songId'],
        'copyrightId': item['copyrightId'],
        'source': 'mg',
        'interval': interval,
        'img': img,
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
}
