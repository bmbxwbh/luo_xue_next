/// 酷狗排行榜 — 对齐 LX Music kg/leaderboard.js
import '../../utils/http_client.dart';
import '../../utils/format_util.dart';
import '../../models/leaderboard_info.dart';

class KgLeaderboard {
  static const int listDetailLimit = 100;

  /// 预设榜单列表 (完整版，对齐 LX Music)
  static final List<LeaderboardInfo> boardList = [
    const LeaderboardInfo(id: 'kg__8888', name: 'TOP500', bangid: '8888', source: 'kg'),
    const LeaderboardInfo(id: 'kg__6666', name: '飙升榜', bangid: '6666', source: 'kg'),
    const LeaderboardInfo(id: 'kg__59703', name: '蜂鸟流行音乐榜', bangid: '59703', source: 'kg'),
    const LeaderboardInfo(id: 'kg__52144', name: '抖音热歌榜', bangid: '52144', source: 'kg'),
    const LeaderboardInfo(id: 'kg__52767', name: '快手热歌榜', bangid: '52767', source: 'kg'),
    const LeaderboardInfo(id: 'kg__24971', name: 'DJ热歌榜', bangid: '24971', source: 'kg'),
    const LeaderboardInfo(id: 'kg__23784', name: '网络红歌榜', bangid: '23784', source: 'kg'),
    const LeaderboardInfo(id: 'kg__44412', name: '说唱先锋榜', bangid: '44412', source: 'kg'),
    const LeaderboardInfo(id: 'kg__31308', name: '内地榜', bangid: '31308', source: 'kg'),
    const LeaderboardInfo(id: 'kg__33160', name: '电音榜', bangid: '33160', source: 'kg'),
    const LeaderboardInfo(id: 'kg__31313', name: '香港地区榜', bangid: '31313', source: 'kg'),
    const LeaderboardInfo(id: 'kg__51341', name: '民谣榜', bangid: '51341', source: 'kg'),
    const LeaderboardInfo(id: 'kg__54848', name: '台湾地区榜', bangid: '54848', source: 'kg'),
    const LeaderboardInfo(id: 'kg__31310', name: '欧美榜', bangid: '31310', source: 'kg'),
    const LeaderboardInfo(id: 'kg__33162', name: 'ACG新歌榜', bangid: '33162', source: 'kg'),
    const LeaderboardInfo(id: 'kg__31311', name: '韩国榜', bangid: '31311', source: 'kg'),
    const LeaderboardInfo(id: 'kg__31312', name: '日本榜', bangid: '31312', source: 'kg'),
    const LeaderboardInfo(id: 'kg__49225', name: '80后热歌榜', bangid: '49225', source: 'kg'),
    const LeaderboardInfo(id: 'kg__49223', name: '90后热歌榜', bangid: '49223', source: 'kg'),
    const LeaderboardInfo(id: 'kg__49224', name: '00后热歌榜', bangid: '49224', source: 'kg'),
    const LeaderboardInfo(id: 'kg__33165', name: '粤语金曲榜', bangid: '33165', source: 'kg'),
    const LeaderboardInfo(id: 'kg__33166', name: '欧美金曲榜', bangid: '33166', source: 'kg'),
    const LeaderboardInfo(id: 'kg__33163', name: '影视金曲榜', bangid: '33163', source: 'kg'),
    const LeaderboardInfo(id: 'kg__51340', name: '伤感榜', bangid: '51340', source: 'kg'),
    const LeaderboardInfo(id: 'kg__35811', name: '会员专享榜', bangid: '35811', source: 'kg'),
    const LeaderboardInfo(id: 'kg__37361', name: '雷达榜', bangid: '37361', source: 'kg'),
    const LeaderboardInfo(id: 'kg__21101', name: '分享榜', bangid: '21101', source: 'kg'),
    const LeaderboardInfo(id: 'kg__46910', name: '综艺新歌榜', bangid: '46910', source: 'kg'),
    const LeaderboardInfo(id: 'kg__30972', name: '酷狗音乐人原创榜', bangid: '30972', source: 'kg'),
    const LeaderboardInfo(id: 'kg__60170', name: '闽南语榜', bangid: '60170', source: 'kg'),
    const LeaderboardInfo(id: 'kg__65234', name: '儿歌榜', bangid: '65234', source: 'kg'),
    const LeaderboardInfo(id: 'kg__4681', name: '美国BillBoard榜', bangid: '4681', source: 'kg'),
    const LeaderboardInfo(id: 'kg__25028', name: 'Beatport电子舞曲榜', bangid: '25028', source: 'kg'),
    const LeaderboardInfo(id: 'kg__4680', name: '英国单曲榜', bangid: '4680', source: 'kg'),
    const LeaderboardInfo(id: 'kg__38623', name: '韩国Melon音乐榜', bangid: '38623', source: 'kg'),
    const LeaderboardInfo(id: 'kg__42807', name: 'joox本地热歌榜', bangid: '42807', source: 'kg'),
    const LeaderboardInfo(id: 'kg__36107', name: '小语种热歌榜', bangid: '36107', source: 'kg'),
    const LeaderboardInfo(id: 'kg__4673', name: '日本公信榜', bangid: '4673', source: 'kg'),
    const LeaderboardInfo(id: 'kg__46868', name: '日本SPACE SHOWER榜', bangid: '46868', source: 'kg'),
    const LeaderboardInfo(id: 'kg__42808', name: 'KKBOX风云榜', bangid: '42808', source: 'kg'),
    const LeaderboardInfo(id: 'kg__60171', name: '越南语榜', bangid: '60171', source: 'kg'),
    const LeaderboardInfo(id: 'kg__60172', name: '泰语榜', bangid: '60172', source: 'kg'),
    const LeaderboardInfo(id: 'kg__59895', name: 'R&B榜', bangid: '59895', source: 'kg'),
    const LeaderboardInfo(id: 'kg__59896', name: '摇滚榜', bangid: '59896', source: 'kg'),
    const LeaderboardInfo(id: 'kg__59897', name: '爵士榜', bangid: '59897', source: 'kg'),
    const LeaderboardInfo(id: 'kg__59898', name: '乡村音乐榜', bangid: '59898', source: 'kg'),
    const LeaderboardInfo(id: 'kg__59900', name: '纯音乐榜', bangid: '59900', source: 'kg'),
    const LeaderboardInfo(id: 'kg__59899', name: '古典榜', bangid: '59899', source: 'kg'),
    const LeaderboardInfo(id: 'kg__22603', name: '5sing音乐榜', bangid: '22603', source: 'kg'),
    const LeaderboardInfo(id: 'kg__21335', name: '繁星音乐榜', bangid: '21335', source: 'kg'),
    const LeaderboardInfo(id: 'kg__33161', name: '古风新歌榜', bangid: '33161', source: 'kg'),
  ];

  /// 获取榜单列表
  static Future<List<LeaderboardInfo>> getBoards() async {
    return boardList;
  }

  /// 构建 URL
  static String _getUrl(int p, String id, int limit) {
    return 'http://mobilecdnbj.kugou.com/api/v3/rank/song?version=9108&ranktype=1&plat=0&pagesize=$limit&area_code=1&page=$p&rankid=$id&with_res_tag=0&show_portrait_mv=1';
  }

  /// 获取榜单数据
  static Future<Map<String, dynamic>> getList(String bangid, int page, {int retryNum = 0}) async {
    if (retryNum > 3) throw Exception('try max num');

    try {
      final resp = await HttpClient.get(_getUrl(page, bangid, listDetailLimit));
      if (!resp.ok || resp.jsonBody == null) return getList(bangid, page, retryNum: retryNum + 1);

      final body = resp.jsonBody;
      if (body['errcode'] != 0) return getList(bangid, page, retryNum: retryNum + 1);

      final data = body['data'];
      final total = data['total'] ?? 0;
      final list = _filterData(data['info'] as List);

      return {
        'total': total,
        'list': list,
        'limit': listDetailLimit,
        'page': page,
        'source': 'kg',
      };
    } catch (_) {
      return getList(bangid, page, retryNum: retryNum + 1);
    }
  }

  static String _getSinger(List? authors) {
    if (authors == null || authors.isEmpty) return '';
    return authors.map((s) => s['author_name'] ?? '').join('、');
  }

  static List<Map<String, dynamic>> _filterData(List rawList) {
    return rawList.map((item) {
      final types = <Map<String, dynamic>>[];
      final typesMap = <String, Map<String, dynamic>>{};

      if ((item['filesize'] ?? 0) != 0) {
        final size = sizeFormate(item['filesize']);
        types.add({'type': '128k', 'size': size, 'hash': item['hash']});
        typesMap['128k'] = {'size': size, 'hash': item['hash']};
      }
      if ((item['320filesize'] ?? 0) != 0) {
        final size = sizeFormate(item['320filesize']);
        types.add({'type': '320k', 'size': size, 'hash': item['320hash']});
        typesMap['320k'] = {'size': size, 'hash': item['320hash']};
      }
      if ((item['sqfilesize'] ?? 0) != 0) {
        final size = sizeFormate(item['sqfilesize']);
        types.add({'type': 'flac', 'size': size, 'hash': item['sqhash']});
        typesMap['flac'] = {'size': size, 'hash': item['sqhash']};
      }
      if ((item['filesize_high'] ?? 0) != 0) {
        final size = sizeFormate(item['filesize_high']);
        types.add({'type': 'flac24bit', 'size': size, 'hash': item['hash_high']});
        typesMap['flac24bit'] = {'size': size, 'hash': item['hash_high']};
      }

      return {
        'singer': _getSinger(item['authors']),
        'name': decodeName(item['songname']?.toString()),
        'albumName': decodeName(item['remark']?.toString()),
        'albumId': item['album_id'],
        'songmid': item['audio_id']?.toString() ?? '',
        'source': 'kg',
        'interval': formatPlayTime(item['duration'] ?? 0),
        'img': null,
        'lrc': null,
        'hash': item['hash'],
        'otherSource': null,
        'types': types,
        '_types': typesMap,
        'typeUrl': <String, dynamic>{},
      };
    }).toList();
  }

  /// 获取详情页 URL
  static String getDetailPageUrl(String id) {
    final bangid = id.replaceFirst('kg__', '');
    return 'https://www.kugou.com/yy/rank/home/1-$bangid.html';
  }
}
