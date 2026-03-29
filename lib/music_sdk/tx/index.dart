/// QQ音乐 SDK 入口
export 'music_search.dart';
export 'lyric.dart';
export 'hot_search.dart';
export 'leaderboard.dart';
export 'song_list.dart';
export 'tip_search.dart';

import 'music_search.dart';
import 'lyric.dart';
import 'hot_search.dart';
import 'leaderboard.dart';
import 'song_list.dart';
import 'tip_search.dart';
import '../../models/search_result.dart';

/// QQ音乐 SDK
class TxSdk {
  static const source = 'tx';

  /// 搜索音乐
  static Future<SearchResult> search(String keyword, {int page = 1, int limit = 30}) {
    return TxMusicSearch.search(keyword, page: page, pageSize: limit);
  }

  /// 获取歌词
  static Future<Map<String, dynamic>> getLyric(Map<String, dynamic> songInfo) async {
    final songmid = songInfo['songmid']?.toString() ?? '';
    final lyricInfo = await TxLyric.getLyric(songmid);
    return {
      'lyric': lyricInfo.lyric,
      'tlyric': lyricInfo.tlyric,
      'rlyric': '',
      'lxlyric': '',
    };
  }

  /// 获取封面 (直接拼接URL，无需API)
  static Future<String?> getPic(Map<String, dynamic> songInfo) async {
    final albumMid = songInfo['albumMid'] ?? '';
    if (albumMid.isEmpty) return null;
    return 'https://y.gtimg.cn/music/photo_new/T002R300x300M000$albumMid.jpg';
  }

  /// 获取热搜
  static Future<List<String>> getHotSearch() {
    return TxHotSearch.getHotSearch();
  }

  /// 获取排行榜列表
  static Future<List> getBoards() {
    return TxLeaderboard.getBoards();
  }

  /// 获取排行榜数据
  static Future<Map<String, dynamic>> getLeaderboardList(String bangid, int page) {
    // tx使用 bangId(int) + period(String) 格式，这里做兼容
    final bangId = int.tryParse(bangid) ?? 0;
    return TxLeaderboard.getList(bangId, '');
  }

  /// 获取歌单列表
  static Future<Map<String, dynamic>> getSongList(String sortId, String? tagId, int page) {
    final sort = int.tryParse(sortId) ?? 5;
    return TxSongList.getList(sort, tagId: tagId, page: page);
  }

  /// 搜索歌单
  static Future<Map<String, dynamic>> searchSongList(String text, int page, {int limit = 20}) {
    return TxSongList.search(text, page: page, limit: limit);
  }

  /// 获取搜索提示
  static Future<List<String>> getTipSearch(String keyword) {
    return TxTipSearch.search(keyword);
  }
}
