import '../../models/enums.dart';
import '../../models/song_model.dart';
import '../../store/search_store.dart';
import '../../music_sdk/index.dart';
import '../../utils/global.dart';

/// 搜索结果
class MusicSearchResult {
  final List<SongModel> list;
  final int allPage;
  final int limit;
  final int total;
  final String source;

  const MusicSearchResult({
    required this.list,
    required this.allPage,
    required this.limit,
    required this.total,
    required this.source,
  });
}

/// 搜索业务 — 对齐 LX Music core/search/music.ts
/// 使用 MusicSdk 统一调度各源搜索
class MusicSearchService {
  final SearchStore _searchStore;

  /// 各源搜索结果缓存
  final Map<String, MusicSearchResult> _cache = {};

  /// 每页数量
  static const int pageSize = 30;

  MusicSearchService(this._searchStore);

  /// 搜索歌曲
  /// [keyword] 搜索关键词
  /// [source] 音乐源
  /// [page] 页码 (从1开始)
  Future<List<SongModel>> search(String keyword, MusicSource source, int page) async {
    if (keyword.isEmpty) return [];

    final cacheKey = '${source.id}__$page$keyword';

    // 检查缓存
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!.list;
    }

    _searchStore.setSearchText(keyword);

    try {
      List<SongModel> results;

      if (source.id == 'all') {
        results = await _searchAll(keyword, page);
      } else {
        results = await _searchSingle(keyword, source, page);
      }

      _searchStore.addHistory(keyword);

      // 缓存结果
      _cache[cacheKey] = MusicSearchResult(
        list: results,
        allPage: (results.length / pageSize).ceil() + 1,
        limit: pageSize,
        total: results.length,
        source: source.id,
      );

      return results;
    } catch (e) {
      print('search error: $e');
      rethrow;
    }
  }

  /// 搜索单个源 — 对齐 LX Music musicSdk[source].musicSearch.search()
  Future<List<SongModel>> _searchSingle(String keyword, MusicSource source, int page) async {
    try {
      // MF 模式：如果 MF 插件支持搜索，走 MF 插件
      if (globalOnlineMusicService.isMfSearchAvailable) {
        final results = await globalOnlineMusicService.mfSearch(keyword, page, 'music');
        if (results.isNotEmpty) {
          return results.map((item) {
            // MF 返回: id, platform, title, artist, album, artwork, duration
            final mfSource = MusicSource.fromId(item['platform']?.toString() ?? source.id);
            final songmid = item['id']?.toString() ?? '';
            return SongModel.fromLxJson({
              'songmid': songmid,
              'name': item['title'] ?? '',
              'singer': item['artist'] ?? '',
              'albumName': item['album'] ?? '',
              'picUrl': item['artwork'] ?? '',
              'img': item['artwork'] ?? '',
              'interval': '',
              '_interval': ((item['duration'] ?? 0) * 1000).toInt(),
              'strMediaMid': songmid,
            }, mfSource);
          }).toList();
        }
      }

      // 内置音源搜索
      final result = await MusicSdk.search(source, keyword, page: page, limit: pageSize);
      return _convertSearchResult(result.list, source);
    } catch (e) {
      print('MusicSdk search error [${source.id}]: $e');
      return [];
    }
  }

  /// 搜索所有源 — 对齐 LX Music Promise.all(task)
  Future<List<SongModel>> _searchAll(String keyword, int page) async {
    final futures = <Future<List<SongModel>>>[];
    for (final source in MusicSource.values) {
      futures.add(
        _searchSingle(keyword, source, page)
            .catchError((_) => <SongModel>[]),
      );
    }
    final results = await Future.wait(futures);
    final allResults = <SongModel>[];
    for (final list in results) {
      allResults.addAll(list);
    }
    return allResults;
  }

  /// 将 MusicSdk 返回的原始 JSON 转换为 SongModel
  /// 对齐 LX Music 的 toNewMusicInfo 格式
  List<SongModel> _convertSearchResult(List<Map<String, dynamic>> rawList, MusicSource source) {
    return rawList.map<SongModel>((item) {
      return SongModel.fromLxJson(item, source);
    }).toList();
  }
}
