/// 网易云音乐 SDK 入口
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

/// 网易云音乐 SDK
class WySdk {
  static const source = 'wy';

  /// 搜索音乐
  static Future<SearchResult> search(String keyword, {int page = 1, int limit = 30}) {
    return WyMusicSearch.search(keyword, page: page, pageSize: limit);
  }

  /// 获取歌词
  static Future<Map<String, dynamic>> getLyric(Map<String, dynamic> songInfo) async {
    final songmid = songInfo['songmid'] ?? '';
    final lyricInfo = await WyLyric.getLyric(songmid);
    return {
      'lyric': lyricInfo.lyric,
      'tlyric': lyricInfo.tlyric,
      'rlyric': '',
      'lxlyric': '',
    };
  }

  /// 获取封面
  static Future<String?> getPic(Map<String, dynamic> songInfo) async {
    return songInfo['img'] ?? songInfo['picUrl'];
  }

  /// 获取热搜
  static Future<List<String>> getHotSearch() {
    return WyHotSearch.getHotSearch();
  }

  /// 获取排行榜列表
  static Future<List> getBoards() {
    return WyLeaderboard.getBoards();
  }

  /// 获取排行榜数据
  static Future<Map<String, dynamic>> getLeaderboardList(String bangid, int page) {
    return WyLeaderboard.getList(bangid);
  }

  /// 获取歌单列表
  static Future<Map<String, dynamic>> getSongList(String sortId, String? tagId, int page) {
    return WySongList.getList(sortId, tagId: tagId, page: page);
  }

  /// 搜索歌单
  static Future<Map<String, dynamic>> searchSongList(String text, int page, {int limit = 20}) {
    return WySongList.search(text, page: page, limit: limit);
  }

  /// 获取搜索提示
  static Future<List<String>> getTipSearch(String keyword) {
    return WyTipSearch.search(keyword);
  }
}
