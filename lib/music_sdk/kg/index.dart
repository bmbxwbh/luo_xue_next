/// 酷狗音乐 SDK 入口
export 'music_search.dart';
export 'lyric.dart';
export 'pic.dart';
export 'hot_search.dart';
export 'leaderboard.dart';
export 'song_list.dart';
export 'tip_search.dart';
export 'comment.dart';

import 'music_search.dart';
import 'lyric.dart';
import 'pic.dart';
import 'hot_search.dart';
import 'leaderboard.dart';
import 'song_list.dart';
import 'tip_search.dart';
import 'comment.dart';
import '../../models/search_result.dart';
import '../../models/comment_info.dart';

/// 酷狗音乐 SDK
class KgSdk {
  static const source = 'kg';

  /// 搜索音乐
  static Future<SearchResult> search(String keyword, {int page = 1, int limit = 30}) {
    return KgMusicSearch.search(keyword, page: page, limit: limit);
  }

  /// 获取歌词
  static Future<Map<String, dynamic>> getLyric(Map<String, dynamic> songInfo) {
    return KgLyric.getLyric(songInfo);
  }

  /// 获取封面
  static Future<String?> getPic(Map<String, dynamic> songInfo) {
    return KgPic.getPic(songInfo);
  }

  /// 获取热搜
  static Future<List<String>> getHotSearch() {
    return KgHotSearch.getList();
  }

  /// 获取排行榜列表
  static Future<List> getBoards() {
    return KgLeaderboard.getBoards();
  }

  /// 获取排行榜数据
  static Future<Map<String, dynamic>> getLeaderboardList(String bangid, int page) {
    return KgLeaderboard.getList(bangid, page);
  }

  /// 获取歌单标签
  static Future<Map<String, dynamic>> getSongListTags() {
    return KgSongList.getTags();
  }

  /// 获取歌单列表
  static Future<List<Map<String, dynamic>>> getSongList(String sortId, String? tagId, int page) {
    return KgSongList.getSongList(sortId, tagId, page);
  }

  /// 获取推荐歌单
  static Future<List<Map<String, dynamic>>> getSongListRecommend() {
    return KgSongList.getSongListRecommend();
  }

  /// 搜索歌单
  static Future<Map<String, dynamic>> searchSongList(String text, int page, {int limit = 20}) {
    return KgSongList.search(text, page, limit: limit);
  }

  /// 获取搜索提示
  static Future<List<String>> getTipSearch(String keyword) {
    return KgTipSearch.search(keyword);
  }

  /// 获取评论列表
  static Future<CommentResult> getComment({
    required String musicId,
    required String hash,
    int page = 1,
    int limit = 20,
  }) {
    return KgComment.getComment(musicId: musicId, hash: hash, page: page, limit: limit);
  }
}
