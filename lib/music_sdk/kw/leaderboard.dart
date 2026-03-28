/// 酷我排行榜 — 对齐 LX Music kw/leaderboard.js
import '../../utils/http_client.dart';
import '../../utils/format_util.dart';
import '../../utils/wbd_crypto.dart';
import '../../models/leaderboard_info.dart';

class KwLeaderboard {
  static const int limit = 100;
  static final _mInfoRegExp = RegExp(r'level:(\w+),bitrate:(\d+),format:(\w+),size:([\w.]+)');

  /// 预设榜单列表 (完整版，对齐 LX Music)
  static final List<LeaderboardInfo> boardList = [
    const LeaderboardInfo(id: 'kw__93', name: '飙升榜', bangid: '93', source: 'kw'),
    const LeaderboardInfo(id: 'kw__17', name: '新歌榜', bangid: '17', source: 'kw'),
    const LeaderboardInfo(id: 'kw__16', name: '热歌榜', bangid: '16', source: 'kw'),
    const LeaderboardInfo(id: 'kw__158', name: '抖音热歌榜', bangid: '158', source: 'kw'),
    const LeaderboardInfo(id: 'kw__292', name: '铃声榜', bangid: '292', source: 'kw'),
    const LeaderboardInfo(id: 'kw__284', name: '热评榜', bangid: '284', source: 'kw'),
    const LeaderboardInfo(id: 'kw__290', name: 'ACG新歌榜', bangid: '290', source: 'kw'),
    const LeaderboardInfo(id: 'kw__286', name: '台湾KKBOX榜', bangid: '286', source: 'kw'),
    const LeaderboardInfo(id: 'kw__279', name: '冬日暖心榜', bangid: '279', source: 'kw'),
    const LeaderboardInfo(id: 'kw__281', name: '巴士随身听榜', bangid: '281', source: 'kw'),
    const LeaderboardInfo(id: 'kw__255', name: 'KTV点唱榜', bangid: '255', source: 'kw'),
    const LeaderboardInfo(id: 'kw__280', name: '家务进行曲榜', bangid: '280', source: 'kw'),
    const LeaderboardInfo(id: 'kw__282', name: '熬夜修仙榜', bangid: '282', source: 'kw'),
    const LeaderboardInfo(id: 'kw__283', name: '枕边轻音乐榜', bangid: '283', source: 'kw'),
    const LeaderboardInfo(id: 'kw__278', name: '古风音乐榜', bangid: '278', source: 'kw'),
    const LeaderboardInfo(id: 'kw__264', name: 'Vlog音乐榜', bangid: '264', source: 'kw'),
    const LeaderboardInfo(id: 'kw__242', name: '电音榜', bangid: '242', source: 'kw'),
    const LeaderboardInfo(id: 'kw__187', name: '流行趋势榜', bangid: '187', source: 'kw'),
    const LeaderboardInfo(id: 'kw__204', name: '现场音乐榜', bangid: '204', source: 'kw'),
    const LeaderboardInfo(id: 'kw__186', name: 'ACG神曲榜', bangid: '186', source: 'kw'),
    const LeaderboardInfo(id: 'kw__185', name: '最强翻唱榜', bangid: '185', source: 'kw'),
    const LeaderboardInfo(id: 'kw__26', name: '经典怀旧榜', bangid: '26', source: 'kw'),
    const LeaderboardInfo(id: 'kw__104', name: '华语榜', bangid: '104', source: 'kw'),
    const LeaderboardInfo(id: 'kw__182', name: '粤语榜', bangid: '182', source: 'kw'),
    const LeaderboardInfo(id: 'kw__22', name: '欧美榜', bangid: '22', source: 'kw'),
    const LeaderboardInfo(id: 'kw__184', name: '韩语榜', bangid: '184', source: 'kw'),
    const LeaderboardInfo(id: 'kw__183', name: '日语榜', bangid: '183', source: 'kw'),
    const LeaderboardInfo(id: 'kw__145', name: '会员畅听榜', bangid: '145', source: 'kw'),
    const LeaderboardInfo(id: 'kw__153', name: '网红新歌榜', bangid: '153', source: 'kw'),
    const LeaderboardInfo(id: 'kw__64', name: '影视金曲榜', bangid: '64', source: 'kw'),
    const LeaderboardInfo(id: 'kw__176', name: 'DJ嗨歌榜', bangid: '176', source: 'kw'),
    const LeaderboardInfo(id: 'kw__106', name: '真声音', bangid: '106', source: 'kw'),
    const LeaderboardInfo(id: 'kw__12', name: 'Billboard榜', bangid: '12', source: 'kw'),
    const LeaderboardInfo(id: 'kw__49', name: 'iTunes音乐榜', bangid: '49', source: 'kw'),
    const LeaderboardInfo(id: 'kw__180', name: 'beatport电音榜', bangid: '180', source: 'kw'),
    const LeaderboardInfo(id: 'kw__13', name: '英国UK榜', bangid: '13', source: 'kw'),
    const LeaderboardInfo(id: 'kw__164', name: '百大DJ榜', bangid: '164', source: 'kw'),
    const LeaderboardInfo(id: 'kw__246', name: 'YouTube音乐排行榜', bangid: '246', source: 'kw'),
    const LeaderboardInfo(id: 'kw__265', name: '韩国Genie榜', bangid: '265', source: 'kw'),
    const LeaderboardInfo(id: 'kw__14', name: '韩国M-net榜', bangid: '14', source: 'kw'),
    const LeaderboardInfo(id: 'kw__8', name: '香港电台榜', bangid: '8', source: 'kw'),
    const LeaderboardInfo(id: 'kw__15', name: '日本公信榜', bangid: '15', source: 'kw'),
    const LeaderboardInfo(id: 'kw__151', name: '腾讯音乐人原创榜', bangid: '151', source: 'kw'),
  ];

  /// 音质排序
  static List<Map<String, dynamic>> _sortQualityArray(List<Map<String, dynamic>> array) {
    const qualityMap = {'flac24bit': 4, 'flac': 3, '320k': 2, '128k': 1};
    final rawQualityArray = <Map<String, int>>[];
    for (int i = 0; i < array.length; i++) {
      final type = qualityMap[array[i]['type']];
      if (type != null) rawQualityArray.add({'type': type, 'index': i});
    }
    rawQualityArray.sort((a, b) => a['type']!.compareTo(b['type']!));
    return rawQualityArray.map((item) => array[item['index']!]).toList();
  }

  /// 获取榜单列表
  static Future<List<LeaderboardInfo>> getBoards() async {
    return boardList;
  }

  /// 获取榜单数据
  static Future<Map<String, dynamic>> getList(String id, int page, {int retryNum = 0}) async {
    if (retryNum > 3) throw Exception('try max num');

    try {
      final requestBody = {
        'uid': '',
        'devId': '',
        'sFrom': 'kuwo_sdk',
        'user_type': 'AP',
        'carSource': 'kwplayercar_ar_6.0.1.0_apk_keluze.apk',
        'id': id,
        'pn': page - 1,
        'rn': limit,
      };
      final requestUrl = 'https://wbd.kuwo.cn/api/bd/bang/bang_info?${WbdCrypto.buildParam(requestBody)}';
      final resp = await HttpClient.get(requestUrl);

      if (!resp.ok) return getList(id, page, retryNum: retryNum + 1);

      final rawData = WbdCrypto.decodeData(resp.body);
      final data = rawData['data'];
      if (rawData['code'] != 200 || data == null || data['musiclist'] == null) {
        return getList(id, page, retryNum: retryNum + 1);
      }

      final total = int.tryParse(data['total']?.toString() ?? '0') ?? 0;
      final list = _filterData(data['musiclist'] as List);

      return {
        'total': total,
        'list': list,
        'limit': limit,
        'page': page,
        'source': 'kw',
      };
    } catch (_) {
      return getList(id, page, retryNum: retryNum + 1);
    }
  }

  static List<Map<String, dynamic>> _filterData(List rawList) {
    return rawList.map((item) {
      final types = <Map<String, dynamic>>[];
      final typesMap = <String, Map<String, dynamic>>{};
      final qualitys = <String>{};

      final minfo = item['n_minfo']?.toString() ?? '';
      for (final i in minfo.split(';')) {
        final match = _mInfoRegExp.firstMatch(i);
        if (match == null) continue;

        final quality = match.group(2)!;
        final size = match.group(4)!.toUpperCase();
        if (qualitys.contains(quality)) continue;
        qualitys.add(quality);

        switch (quality) {
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

      final sortedTypes = _sortQualityArray(types);

      return {
        'singer': (item['artist']?.toString() ?? '').replaceAll('&', '、'),
        'name': decodeName(item['name']?.toString()),
        'albumName': decodeName(item['album']?.toString()),
        'albumId': item['albumId'],
        'songmid': item['id']?.toString() ?? '',
        'source': 'kw',
        'interval': formatPlayTime(int.tryParse(item['duration']?.toString() ?? '0') ?? 0),
        'img': item['pic'],
        'lrc': null,
        'otherSource': null,
        'types': sortedTypes,
        '_types': typesMap,
        'typeUrl': <String, dynamic>{},
      };
    }).toList();
  }
}
