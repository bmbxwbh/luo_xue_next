import '../models/enums.dart';
import '../models/song_model.dart';
import '../models/playlist_info.dart';
import '../utils/http_client.dart';
import '../utils/format_util.dart';

/// 歌单详情
class SonglistDetail {
  final List<SongModel> list;
  final int total;
  final int limit;
  final int page;

  const SonglistDetail({
    required this.list,
    required this.total,
    required this.limit,
    required this.page,
  });
}

/// 歌单业务 — 对齐 LX Music core/search/songlist.ts + 歌单推荐
class SonglistService {
  static const int pageSize = 30;

  /// 获取推荐歌单
  Future<List<PlaylistInfo>> getRecommendPlaylists(MusicSource source, {String? tag, int page = 1}) async {
    switch (source) {
      case MusicSource.kw:
        return _getKwPlaylists(tag: tag, page: page);
      case MusicSource.kg:
        return _getKgPlaylists(tag: tag, page: page);
      case MusicSource.tx:
        return _getTxPlaylists(tag: tag, page: page);
      case MusicSource.wy:
        return _getWyPlaylists(tag: tag, page: page);
      case MusicSource.local:
        throw UnsupportedError("本地音乐不支持此操作");
      case MusicSource.mg:
        return _getMgPlaylists(tag: tag, page: page);
    }
  }

  /// 获取歌单详情（歌曲列表）
  Future<SonglistDetail> getPlaylistSongs(MusicSource source, String playlistId, int page) async {
    switch (source) {
      case MusicSource.kw:
        return _getKwPlaylistSongs(playlistId, page);
      case MusicSource.kg:
        return _getKgPlaylistSongs(playlistId, page);
      case MusicSource.tx:
        return _getTxPlaylistSongs(playlistId, page);
      case MusicSource.wy:
        return _getWyPlaylistSongs(playlistId, page);
      case MusicSource.local:
        throw UnsupportedError("本地音乐不支持此操作");
      case MusicSource.mg:
        return _getMgPlaylistSongs(playlistId, page);
    }
  }

  // ============ 酷我 ============

  Future<List<PlaylistInfo>> _getKwPlaylists({String? tag, int page = 1}) async {
    final url = tag != null && tag.isNotEmpty
        ? 'http://www.kuwo.cn/api/www/classify/playlist/getRcmPlayList?pn=$page&rn=$pageSize&order=$tag&httpsStatus=1'
        : 'http://www.kuwo.cn/api/www/classify/playlist/getRcmPlayList?pn=$page&rn=$pageSize&order=new&httpsStatus=1';

    final resp = await HttpClient.get(url, headers: {
      'Referer': 'http://www.kuwo.cn/',
      'csrf': '',
    });

    if (!resp.ok || resp.jsonBody is! Map) return [];

    final data = resp.jsonBody as Map<String, dynamic>;
    if (data['code'] != 200 || data['data'] is! Map) return [];

    final list = data['data']['data'] as List? ?? [];

    return list.map<PlaylistInfo>((item) {
      final m = item as Map<String, dynamic>;
      return PlaylistInfo(
        playCount: formatPlayCount(m['listencnt']),
        id: m['id']?.toString() ?? '',
        author: decodeName(m['uname']?.toString()),
        name: decodeName(m['name']?.toString()),
        img: m['img']?.toString() ?? '',
        total: m['total'] is int ? m['total'] : 0,
        desc: m['info']?.toString() ?? '',
        source: 'kw',
      );
    }).toList();
  }

  Future<SonglistDetail> _getKwPlaylistSongs(String playlistId, int page) async {
    const limit = 30;
    final url = 'http://www.kuwo.cn/api/www/playlist/playListInfo?pid=$playlistId&pn=$page&rn=$limit&httpsStatus=1';
    final resp = await HttpClient.get(url, headers: {
      'Referer': 'http://www.kuwo.cn/',
      'csrf': '',
    });

    if (!resp.ok || resp.jsonBody is! Map) {
      return const SonglistDetail(list: [], total: 0, limit: limit, page: 1);
    }

    final data = resp.jsonBody as Map<String, dynamic>;
    final total = data['data'] is Map ? (data['data']['total'] as int? ?? 0) : 0;

    final musicListUrl = 'http://www.kuwo.cn/api/www/playlist/playListInfo?pid=$playlistId&pn=$page&rn=$limit&httpsStatus=1';
    final musicResp = await HttpClient.get(musicListUrl, headers: {
      'Referer': 'http://www.kuwo.cn/',
      'csrf': '',
    });

    if (!musicResp.ok || musicResp.jsonBody is! Map) {
      return SonglistDetail(list: [], total: total, limit: limit, page: page);
    }

    final musicData = musicResp.jsonBody as Map<String, dynamic>;
    final list = (musicData['data'] as Map?)?['musicList'] as List? ?? [];

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
        ),
      );
    }).toList();

    return SonglistDetail(list: songs, total: total, limit: limit, page: page);
  }

  // ============ 酷狗 ============

  Future<List<PlaylistInfo>> _getKgPlaylists({String? tag, int page = 1}) async {
    final url = 'https://www.kugou.com/yy/special/index/getRecommend?categoryid=0&showtype=0&page=$page';
    final resp = await HttpClient.get(url);

    if (!resp.ok || resp.jsonBody is! Map) return [];

    final data = resp.jsonBody as Map<String, dynamic>;
    final list = data['data'] as List? ?? [];

    return list.map<PlaylistInfo>((item) {
      final m = item as Map<String, dynamic>;
      return PlaylistInfo(
        playCount: formatPlayCount(m['play_count']),
        id: m['specialid']?.toString() ?? '',
        author: decodeName(m['nickname']?.toString()),
        name: decodeName(m['specialname']?.toString()),
        img: m['img']?.toString().replaceFirst('{size}', '480') ?? '',
        total: m['songs_count'] is int ? m['songs_count'] : 0,
        source: 'kg',
      );
    }).toList();
  }

  Future<SonglistDetail> _getKgPlaylistSongs(String playlistId, int page) async {
    const limit = 30;
    final url = 'https://www.kugou.com/yy/special/single/$playlistId.html';
    // 实际需要解析HTML
    return const SonglistDetail(list: [], total: 0, limit: limit, page: 1);
  }

  // ============ QQ音乐 ============

  Future<List<PlaylistInfo>> _getTxPlaylists({String? tag, int page = 1}) async {
    final categoryId = tag ?? '10000000';
    final url = 'https://c.y.qq.com/splcloud/fcgi-bin/fcg_get_diss_by_tag.fcg?categoryId=$categoryId&sortId=5&sin=${(page - 1) * pageSize}&ein=${page * pageSize - 1}&format=json';
    final resp = await HttpClient.get(url, headers: {'Referer': 'https://y.qq.com/'});

    if (!resp.ok || resp.jsonBody is! Map) return [];

    final data = resp.jsonBody as Map<String, dynamic>;
    if (data['data'] is! Map || data['data']['list'] is! List) return [];

    final list = data['data']['list'] as List;

    return list.map<PlaylistInfo>((item) {
      final m = item as Map<String, dynamic>;
      return PlaylistInfo(
        playCount: formatPlayCount(m['listennum']),
        id: m['dissid']?.toString() ?? '',
        author: decodeName(m['creator'] is Map ? (m['creator']['name']?.toString()) : ''),
        name: decodeName(m['dissname']?.toString()),
        img: m['imgurl']?.toString() ?? '',
        total: m['song_count'] is int ? m['song_count'] : 0,
        source: 'tx',
      );
    }).toList();
  }

  Future<SonglistDetail> _getTxPlaylistSongs(String playlistId, int page) async {
    const limit = 30;
    return const SonglistDetail(list: [], total: 0, limit: limit, page: 1);
  }

  // ============ 网易云 ============

  Future<List<PlaylistInfo>> _getWyPlaylists({String? tag, int page = 1}) async {
    final cat = tag ?? '全部';
    final offset = (page - 1) * pageSize;
    final url = 'https://music.163.com/api/playlist/list?cat=$cat&order=hot&offset=$offset&limit=$pageSize';
    final resp = await HttpClient.get(url, headers: {
      'Referer': 'https://music.163.com/',
    });

    if (!resp.ok || resp.jsonBody is! Map) return [];

    final data = resp.jsonBody as Map<String, dynamic>;
    if (data['playlists'] is! List) return [];

    final list = data['playlists'] as List;

    return list.map<PlaylistInfo>((item) {
      final m = item as Map<String, dynamic>;
      final creator = m['creator'] as Map<String, dynamic>?;

      return PlaylistInfo(
        playCount: formatPlayCount(m['playCount']),
        id: m['id']?.toString() ?? '',
        author: decodeName(creator?['nickname']?.toString()),
        name: decodeName(m['name']?.toString()),
        img: m['coverImgUrl']?.toString() ?? '',
        total: m['trackCount'] is int ? m['trackCount'] : 0,
        desc: m['description']?.toString() ?? '',
        source: 'wy',
      );
    }).toList();
  }

  Future<SonglistDetail> _getWyPlaylistSongs(String playlistId, int page) async {
    const limit = 100;
    final url = 'https://music.163.com/api/playlist/detail?id=$playlistId';
    final resp = await HttpClient.get(url, headers: {
      'Referer': 'https://music.163.com/',
    });

    if (!resp.ok || resp.jsonBody is! Map) {
      return const SonglistDetail(list: [], total: 0, limit: limit, page: 1);
    }

    final data = resp.jsonBody as Map<String, dynamic>;
    final result = data['result'] as Map<String, dynamic>?;
    if (result == null) {
      return const SonglistDetail(list: [], total: 0, limit: limit, page: 1);
    }

    final total = result['trackCount'] is int ? result['trackCount'] : 0;
    final tracks = result['tracks'] as List? ?? [];

    final songs = tracks.map<SongModel>((item) {
      final m = item as Map<String, dynamic>;
      final songId = m['id']?.toString() ?? '';
      final artists = m['artists'] as List?;
      final singerStr = formatSingerName(artists, nameKey: 'name', join: '/');

      return SongModel(
        id: 'wy_$songId',
        name: decodeName(m['name']?.toString()),
        singer: singerStr,
        source: MusicSource.wy,
        interval: formatPlayTime((m['duration'] is int ? m['duration'] : 0) ~/ 1000),
        intervalSec: (m['duration'] is int ? m['duration'] : 0) ~/ 1000,
        meta: MusicInfoMeta(
          songId: songId,
          albumName: decodeName(m['album'] is Map ? (m['album']['name']?.toString()) : ''),
          picUrl: m['album'] is Map ? m['album']['picUrl']?.toString() : null,
          qualitys: const [MusicType(type: '128k')],
        ),
      );
    }).toList();

    // 分页处理
    final start = (page - 1) * limit;
    final end = start + limit;
    final pagedSongs = songs.length > start
        ? songs.sublist(start, end > songs.length ? songs.length : end)
        : <SongModel>[];

    return SonglistDetail(list: pagedSongs, total: total, limit: limit, page: page);
  }

  // ============ 咪咕 ============

  Future<List<PlaylistInfo>> _getMgPlaylists({String? tag, int page = 1}) async {
    return [];
  }

  Future<SonglistDetail> _getMgPlaylistSongs(String playlistId, int page) async {
    const limit = 30;
    return const SonglistDetail(list: [], total: 0, limit: limit, page: 1);
  }
}
