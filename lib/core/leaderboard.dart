import '../models/enums.dart';
import '../models/song_model.dart';
import '../models/leaderboard_info.dart';
import '../utils/http_client.dart';
import '../utils/format_util.dart';

/// 榜单详情
class BoardDetail {
  final List<SongModel> list;
  final int total;
  final int limit;
  final int page;
  final String source;

  const BoardDetail({
    required this.list,
    required this.total,
    required this.limit,
    required this.page,
    required this.source,
  });
}

/// 排行榜业务 — 对齐 LX Music core/leaderboard.dart
class LeaderboardService {

  /// 获取榜单列表
  Future<List<LeaderboardInfo>> getBoards(MusicSource source) async {
    switch (source) {
      case MusicSource.kw:
        return _getKwBoards();
      case MusicSource.kg:
        return _getKgBoards();
      case MusicSource.tx:
        return _getTxBoards();
      case MusicSource.wy:
        return _getWyBoards();
      case MusicSource.mg:
        return _getMgBoards();
      case MusicSource.local:
        return [];
    }
  }

  /// 获取榜单歌曲
  Future<BoardDetail> getBoardSongs(MusicSource source, String boardId, int page) async {
    switch (source) {
      case MusicSource.kw:
        return _getKwBoardSongs(boardId, page);
      case MusicSource.kg:
        return _getKgBoardSongs(boardId, page);
      case MusicSource.tx:
        return _getTxBoardSongs(boardId, page);
      case MusicSource.wy:
        return _getWyBoardSongs(boardId, page);
      case MusicSource.mg:
        return _getMgBoardSongs(boardId, page);
      case MusicSource.local:
        return BoardDetail(list: [], total: 0, limit: 0, page: 0, source: 'local');
    }
  }

  // ============ 酷我 ============

  Future<List<LeaderboardInfo>> _getKwBoards() async {
    return const [
      LeaderboardInfo(id: 'kw__16', name: '飙升榜', bangid: '16', source: 'kw'),
      LeaderboardInfo(id: 'kw__17', name: '新歌榜', bangid: '17', source: 'kw'),
      LeaderboardInfo(id: 'kw__18', name: '热歌榜', bangid: '18', source: 'kw'),
      LeaderboardInfo(id: 'kw__24', name: '抖音热歌', bangid: '24', source: 'kw'),
      LeaderboardInfo(id: 'kw__26', name: 'ACG新歌榜', bangid: '26', source: 'kw'),
      LeaderboardInfo(id: 'kw__27', name: 'VOCALOID榜', bangid: '27', source: 'kw'),
      LeaderboardInfo(id: 'kw__28', name: '电音榜', bangid: '28', source: 'kw'),
      LeaderboardInfo(id: 'kw__29', name: '说唱榜', bangid: '29', source: 'kw'),
      LeaderboardInfo(id: 'kw__30', name: '国风榜', bangid: '30', source: 'kw'),
      LeaderboardInfo(id: 'kw__31', name: '民谣榜', bangid: '31', source: 'kw'),
      LeaderboardInfo(id: 'kw__32', name: '摇滚榜', bangid: '32', source: 'kw'),
      LeaderboardInfo(id: 'kw__33', name: '古风榜', bangid: '33', source: 'kw'),
      LeaderboardInfo(id: 'kw__34', name: '爵士榜', bangid: '34', source: 'kw'),
      LeaderboardInfo(id: 'kw__35', name: '影视金曲榜', bangid: '35', source: 'kw'),
      LeaderboardInfo(id: 'kw__36', name: '经典老歌榜', bangid: '36', source: 'kw'),
    ];
  }

  Future<BoardDetail> _getKwBoardSongs(String boardId, int page) async {
    const limit = 30;
    final url = 'http://www.kuwo.cn/api/www/bang/bang/musicList?bangId=$boardId&pn=$page&rn=$limit&httpsStatus=1';
    final resp = await HttpClient.get(url, headers: {
      'Referer': 'http://www.kuwo.cn/',
      'csrf': '',
    });

    if (!resp.ok || resp.jsonBody is! Map) {
      return const BoardDetail(list: [], total: 0, limit: limit, page: 1, source: 'kw');
    }

    final data = resp.jsonBody as Map<String, dynamic>;
    if (data['code'] != 200 || data['data'] is! Map) {
      return const BoardDetail(list: [], total: 0, limit: limit, page: 1, source: 'kw');
    }

    final total = data['data']['total'] is int ? data['data']['total'] as int : 0;
    final list = data['data']['musicList'] as List? ?? [];

    final songs = list.map<SongModel>((item) {
      final m = item as Map<String, dynamic>;
      final musicrid = m['musicrid']?.toString() ?? '';
      final songmid = musicrid.replaceFirst('MUSIC_', '');

      return SongModel(
        id: 'kw_$songmid',
        name: decodeName(m['name']?.toString()),
        singer: decodeName(m['artist']?.toString()),
        source: MusicSource.kw,
        interval: m['songTimeMinutes']?.toString() ?? '',
        intervalSec: m['duration'] is int ? m['duration'] : 0,
        meta: MusicInfoMeta(
          songId: songmid,
          albumName: decodeName(m['album']?.toString()),
          picUrl: m['pic'],
          qualitys: const [MusicType(type: '128k')],
          albumId: m['albumid']?.toString(),
        ),
      );
    }).toList();

    return BoardDetail(list: songs, total: total, limit: limit, page: page, source: 'kw');
  }

  // ============ 酷狗 ============

  Future<List<LeaderboardInfo>> _getKgBoards() async {
    return const [
      LeaderboardInfo(id: 'kg__6666', name: '飙升榜', bangid: '6666', source: 'kg'),
      LeaderboardInfo(id: 'kg__8888', name: 'TOP500', bangid: '8888', source: 'kg'),
      LeaderboardInfo(id: 'kg__23784', name: '蜂鸟流行音乐榜', bangid: '23784', source: 'kg'),
      LeaderboardInfo(id: 'kg__24971', name: '抖音热歌榜', bangid: '24971', source: 'kg'),
      LeaderboardInfo(id: 'kg__21342', name: '网络红歌榜', bangid: '21342', source: 'kg'),
      LeaderboardInfo(id: 'kg__31308', name: '说唱榜', bangid: '31308', source: 'kg'),
      LeaderboardInfo(id: 'kg__31310', name: '国风榜', bangid: '31310', source: 'kg'),
      LeaderboardInfo(id: 'kg__31312', name: '民谣榜', bangid: '31312', source: 'kg'),
      LeaderboardInfo(id: 'kg__31313', name: '摇滚榜', bangid: '31313', source: 'kg'),
      LeaderboardInfo(id: 'kg__31314', name: '古风榜', bangid: '31314', source: 'kg'),
      LeaderboardInfo(id: 'kg__31315', name: '电音榜', bangid: '31315', source: 'kg'),
    ];
  }

  Future<BoardDetail> _getKgBoardSongs(String boardId, int page) async {
    const limit = 30;
    final url = 'https://www.kugou.com/yy/rank/home/$boardId-$page.html?from=rank';
    // 简化处理，实际需要解析HTML或使用API
    return const BoardDetail(list: [], total: 0, limit: limit, page: 1, source: 'kg');
  }

  // ============ QQ音乐 ============

  Future<List<LeaderboardInfo>> _getTxBoards() async {
    return const [
      LeaderboardInfo(id: 'tx__26', name: '热歌榜', bangid: '26', source: 'tx'),
      LeaderboardInfo(id: 'tx__27', name: '新歌榜', bangid: '27', source: 'tx'),
      LeaderboardInfo(id: 'tx__4', name: '流行指数榜', bangid: '4', source: 'tx'),
      LeaderboardInfo(id: 'tx__5', name: '内地榜', bangid: '5', source: 'tx'),
      LeaderboardInfo(id: 'tx__6', name: '港台榜', bangid: '6', source: 'tx'),
      LeaderboardInfo(id: 'tx__16', name: '欧美榜', bangid: '16', source: 'tx'),
      LeaderboardInfo(id: 'tx__36', name: '抖音榜', bangid: '36', source: 'tx'),
      LeaderboardInfo(id: 'tx__28', name: '说唱榜', bangid: '28', source: 'tx'),
      LeaderboardInfo(id: 'tx__29', name: '国风榜', bangid: '29', source: 'tx'),
      LeaderboardInfo(id: 'tx__30', name: '民谣榜', bangid: '30', source: 'tx'),
    ];
  }

  Future<BoardDetail> _getTxBoardSongs(String boardId, int page) async {
    const limit = 30;
    return const BoardDetail(list: [], total: 0, limit: limit, page: 1, source: 'tx');
  }

  // ============ 网易云 ============

  Future<List<LeaderboardInfo>> _getWyBoards() async {
    return const [
      LeaderboardInfo(id: 'wy__3779629', name: '新歌榜', bangid: '3779629', source: 'wy'),
      LeaderboardInfo(id: 'wy__3778678', name: '热歌榜', bangid: '3778678', source: 'wy'),
      LeaderboardInfo(id: 'wy__2884035', name: '原创榜', bangid: '2884035', source: 'wy'),
      LeaderboardInfo(id: 'wy__19723756', name: '飙升榜', bangid: '19723756', source: 'wy'),
      LeaderboardInfo(id: 'wy__3779629', name: '说唱榜', bangid: '3779629', source: 'wy'),
      LeaderboardInfo(id: 'wy__991319590', name: '国风榜', bangid: '991319590', source: 'wy'),
      LeaderboardInfo(id: 'wy__71384707', name: '古典榜', bangid: '71384707', source: 'wy'),
      LeaderboardInfo(id: 'wy__71385702', name: '电子榜', bangid: '71385702', source: 'wy'),
      LeaderboardInfo(id: 'wy__1978921795', name: '摇滚榜', bangid: '1978921795', source: 'wy'),
      LeaderboardInfo(id: 'wy__5213356842', name: '民谣榜', bangid: '5213356842', source: 'wy'),
    ];
  }

  Future<BoardDetail> _getWyBoardSongs(String boardId, int page) async {
    const limit = 30;
    return const BoardDetail(list: [], total: 0, limit: limit, page: 1, source: 'wy');
  }

  // ============ 咪咕 ============

  Future<List<LeaderboardInfo>> _getMgBoards() async {
    return const [
      LeaderboardInfo(id: 'mg__1', name: '新歌榜', bangid: '1', source: 'mg'),
      LeaderboardInfo(id: 'mg__2', name: '热歌榜', bangid: '2', source: 'mg'),
    ];
  }

  Future<BoardDetail> _getMgBoardSongs(String boardId, int page) async {
    const limit = 30;
    return const BoardDetail(list: [], total: 0, limit: limit, page: 1, source: 'mg');
  }
}
