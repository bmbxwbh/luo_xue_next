import '../../utils/http_client.dart';
import '../../utils/eapi_encryptor.dart';
import '../../utils/format_util.dart';

/// 网易云音乐排行榜 — 对齐 LX Music wy/leaderboard.js
/// API: https://music.163.com/weapi/v3/playlist/detail
class WyLeaderboard {
  /// 预设榜单列表
  static const List<Map<String, dynamic>> boardList = [
    {'id': 'wy__19723756', 'name': '飙升榜', 'bangid': '19723756'},
    {'id': 'wy__3779629', 'name': '新歌榜', 'bangid': '3779629'},
    {'id': 'wy__2884035', 'name': '原创榜', 'bangid': '2884035'},
    {'id': 'wy__3778678', 'name': '热歌榜', 'bangid': '3778678'},
    {'id': 'wy__991319590', 'name': '说唱榜', 'bangid': '991319590'},
    {'id': 'wy__71384707', 'name': '古典榜', 'bangid': '71384707'},
    {'id': 'wy__1978921795', 'name': '电音榜', 'bangid': '1978921795'},
    {'id': 'wy__5453912201', 'name': '黑胶VIP爱听榜', 'bangid': '5453912201'},
    {'id': 'wy__71385702', 'name': 'ACG榜', 'bangid': '71385702'},
    {'id': 'wy__745956260', 'name': '韩语榜', 'bangid': '745956260'},
    {'id': 'wy__10520166', 'name': '国电榜', 'bangid': '10520166'},
    {'id': 'wy__180106', 'name': 'UK排行榜周榜', 'bangid': '180106'},
    {'id': 'wy__60198', 'name': '美国Billboard榜', 'bangid': '60198'},
    {'id': 'wy__3812895', 'name': 'Beatport全球电子舞曲榜', 'bangid': '3812895'},
    {'id': 'wy__21845217', 'name': 'KTV唛榜', 'bangid': '21845217'},
    {'id': 'wy__60131', 'name': '日本Oricon榜', 'bangid': '60131'},
    {'id': 'wy__2809513713', 'name': '欧美热歌榜', 'bangid': '2809513713'},
    {'id': 'wy__2809577409', 'name': '欧美新歌榜', 'bangid': '2809577409'},
    {'id': 'wy__27135204', 'name': '法国 NRJ Vos Hits 周榜', 'bangid': '27135204'},
    {'id': 'wy__3001835560', 'name': 'ACG动画榜', 'bangid': '3001835560'},
    {'id': 'wy__3001795926', 'name': 'ACG游戏榜', 'bangid': '3001795926'},
    {'id': 'wy__3001890046', 'name': 'ACG VOCALOID榜', 'bangid': '3001890046'},
    {'id': 'wy__3112516681', 'name': '中国新乡村音乐排行榜', 'bangid': '3112516681'},
    {'id': 'wy__5059644681', 'name': '日语榜', 'bangid': '5059644681'},
    {'id': 'wy__5059633707', 'name': '摇滚榜', 'bangid': '5059633707'},
    {'id': 'wy__5059642708', 'name': '国风榜', 'bangid': '5059642708'},
    {'id': 'wy__5338990334', 'name': '潜力爆款榜', 'bangid': '5338990334'},
    {'id': 'wy__5059661515', 'name': '民谣榜', 'bangid': '5059661515'},
    {'id': 'wy__6688069460', 'name': '听歌识曲榜', 'bangid': '6688069460'},
    {'id': 'wy__6723173524', 'name': '网络热歌榜', 'bangid': '6723173524'},
    {'id': 'wy__6732051320', 'name': '俄语榜', 'bangid': '6732051320'},
    {'id': 'wy__6732014811', 'name': '越南语榜', 'bangid': '6732014811'},
    {'id': 'wy__6886768100', 'name': '中文DJ榜', 'bangid': '6886768100'},
    {'id': 'wy__6939992364', 'name': '俄罗斯top hit流行音乐榜', 'bangid': '6939992364'},
    {'id': 'wy__7095271308', 'name': '泰语榜', 'bangid': '7095271308'},
    {'id': 'wy__7356827205', 'name': 'BEAT排行榜', 'bangid': '7356827205'},
    {'id': 'wy__7325478166', 'name': '编辑推荐榜', 'bangid': '7325478166'},
    {'id': 'wy__7603212484', 'name': 'LOOK直播歌曲榜', 'bangid': '7603212484'},
    {'id': 'wy__7775163417', 'name': '赏音榜', 'bangid': '7775163417'},
    {'id': 'wy__7785123708', 'name': '黑胶VIP新歌榜', 'bangid': '7785123708'},
    {'id': 'wy__7785066739', 'name': '黑胶VIP热歌榜', 'bangid': '7785066739'},
    {'id': 'wy__7785091694', 'name': '黑胶VIP爱搜榜', 'bangid': '7785091694'},
  ];

  /// 简化版榜单（UI展示用）
  static const List<Map<String, dynamic>> shortList = [
    {'id': 'wybsb', 'name': '飙升榜', 'bangid': '19723756'},
    {'id': 'wyrgb', 'name': '热歌榜', 'bangid': '3778678'},
    {'id': 'wyxgb', 'name': '新歌榜', 'bangid': '3779629'},
    {'id': 'wyycb', 'name': '原创榜', 'bangid': '2884035'},
    {'id': 'wygdb', 'name': '古典榜', 'bangid': '71384707'},
    {'id': 'wydouyb', 'name': '抖音榜', 'bangid': '2250011882'},
    {'id': 'wyhyb', 'name': '韩语榜', 'bangid': '745956260'},
    {'id': 'wydianyb', 'name': '电音榜', 'bangid': '1978921795'},
    {'id': 'wydjb', 'name': '电竞榜', 'bangid': '2006508653'},
    {'id': 'wyktvbb', 'name': 'KTV唛榜', 'bangid': '21845217'},
  ];

  /// 获取榜单列表
  static Future<List<Map<String, dynamic>>> getBoards() async {
    return boardList;
  }

  /// 获取榜单详情
  /// API: https://music.163.com/weapi/v3/playlist/detail
  static Future<Map<String, dynamic>> getList(dynamic bangId) async {
    final form = EapiEncryptor.weapi({
      'id': bangId,
      'n': 100000,
      'p': 1,
    });

    final resp = await HttpClient.postForm(
      'https://music.163.com/weapi/v3/playlist/detail',
      headers: {
        'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36',
        'origin': 'https://music.163.com',
      },
      body: form,
    );

    if (resp.statusCode != 200 || resp.jsonBody == null) {
      throw Exception('获取网易云排行榜失败');
    }

    final body = resp.jsonBody;
    if (body['code'] != 200) {
      throw Exception('网易云排行榜API错误');
    }

    final tracks = body['playlist']?['tracks'] as List? ?? [];
    final privileges = body['playlist']?['privileges'] as List? ?? [];
    final list = _filterData(tracks, privileges);

    return {
      'total': list.length,
      'list': list,
      'limit': 100000,
      'page': 1,
      'source': 'wy',
    };
  }

  /// 过滤榜单数据
  static List<Map<String, dynamic>> _filterData(List tracks, List privileges) {
    final list = <Map<String, dynamic>>[];

    for (var i = 0; i < tracks.length; i++) {
      final item = tracks[i];
      final types = <Map<String, String>>[];
      final typesMap = <String, Map<String, String>>{};

      // 查找对应的privilege
      Map<String, dynamic>? privilege;
      if (i < privileges.length && privileges[i]['id'] == item['id']) {
        privilege = privileges[i];
      } else {
        privilege = privileges.cast<Map<String, dynamic>?>().firstWhere(
          (p) => p?['id'] == item['id'],
          orElse: () => null,
        );
      }
      if (privilege == null) continue;

      if (privilege['maxBrLevel'] == 'hires') {
        final size = item['hr'] != null ? sizeFormate(item['hr']['size']) : null;
        types.add({'type': 'flac24bit', 'size': size ?? ''});
        typesMap['flac24bit'] = {'size': size ?? ''};
      }

      final maxbr = privilege['maxbr'] ?? 0;
      if (maxbr >= 999000) {
        types.add({'type': 'flac', 'size': ''});
        typesMap['flac'] = {'size': ''};
      }
      if (maxbr >= 320000) {
        final size = item['h'] != null ? sizeFormate(item['h']['size']) : null;
        types.add({'type': '320k', 'size': size ?? ''});
        typesMap['320k'] = {'size': size ?? ''};
      }
      if (maxbr >= 128000) {
        final size = item['l'] != null ? sizeFormate(item['l']['size']) : null;
        types.add({'type': '128k', 'size': size ?? ''});
        typesMap['128k'] = {'size': size ?? ''};
      }

      types.reversed.toList();

      final ar = item['ar'] as List? ?? [];
      final al = item['al'] ?? {};

      list.add({
        'singer': formatSingerName(ar),
        'name': item['name'] ?? '',
        'albumName': al['name'] ?? '',
        'albumId': al['id'],
        'source': 'wy',
        'interval': formatPlayTime((item['dt'] ?? 0) / 1000),
        'songmid': item['id'],
        'img': al['picUrl'],
        'lrc': null,
        'otherSource': null,
        'types': types,
        '_types': typesMap,
        'typeUrl': {},
      });
    }

    return list;
  }
}
