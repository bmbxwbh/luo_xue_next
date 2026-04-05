/// 咪咕音乐 SDK 入口
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

/// 咪咕音乐 SDK
class MgSdk {
  static const source = 'mg';

  /// 搜索音乐
  static Future<SearchResult> search(String keyword, {int page = 1, int limit = 20}) {
    return MgMusicSearch.search(keyword, page: page, pageSize: limit);
  }

  /// 获取歌词
  static Future<Map<String, dynamic>> getLyric(Map<String, dynamic> songInfo) async {
    final lyricInfo = await MgLyric.getLyric(songInfo);
    return {
      'lyric': lyricInfo.lyric,
      'tlyric': lyricInfo.tlyric,
      'rlyric': '',
      'lxlyric': '',
    };
  }

  /// 获取封面
  static Future<String?> getPic(Map<String, dynamic> songInfo) async {
    String? img = songInfo['img'] ?? songInfo['picUrl'];
    if (img != null && !RegExp(r'https?:').hasMatch(img)) {
      img = 'http://d.musicapp.migu.cn$img';
    }
    return img;
  }

  /// 获取热搜
  static Future<List<String>> getHotSearch() {
    return MgHotSearch.getHotSearch();
  }

  /// 获取排行榜列表
  static Future<List> getBoards() {
    return MgLeaderboard.getBoards();
  }

  /// 获取排行榜数据
  static Future<Map<String, dynamic>> getLeaderboardList(String bangid, int page) {
    return MgLeaderboard.getList(bangid);
  }

  /// 获取歌单列表
  static Future<Map<String, dynamic>> getSongList(String sortId, String? tagId, int page) {
    return MgSongList.getList(sortId, tagId: tagId, page: page);
  }

  /// 搜索歌单
  static Future<Map<String, dynamic>> searchSongList(String text, int page, {int limit = 20}) {
    return MgSongList.search(text, page: page, limit: limit);
  }

  /// 获取搜索提示
  static Future<List<String>> getTipSearch(String keyword) {
    return MgTipSearch.search(keyword);
  }
}
