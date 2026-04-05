/// 酷我音乐 SDK 入口
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

/// 酷我音乐 SDK
class KwSdk {
  static const source = 'kw';

  /// 搜索音乐
  static Future<SearchResult> search(String keyword, {int page = 1, int limit = 30}) {
    return KwMusicSearch.search(keyword, page: page, limit: limit);
  }

  /// 获取歌词
  static Future<Map<String, dynamic>> getLyric(Map<String, dynamic> musicInfo, {bool isGetLyricx = true}) {
    return KwLyric.getLyric(musicInfo, isGetLyricx: isGetLyricx);
  }

  /// 获取封面
  static Future<String?> getPic(Map<String, dynamic> songInfo) {
    return KwPic.getPic(songInfo);
  }

  /// 获取热搜
  static Future<List<String>> getHotSearch() {
    return KwHotSearch.getList();
  }

  /// 获取排行榜列表
  static Future<List> getBoards() {
    return KwLeaderboard.getBoards();
  }

  /// 获取排行榜数据
  static Future<Map<String, dynamic>> getLeaderboardList(String bangid, int page) {
    return KwLeaderboard.getList(bangid, page);
  }

  /// 获取歌单标签
  static Future<Map<String, dynamic>> getSongListTags() {
    return KwSongList.getTags();
  }

  /// 获取歌单列表
  static Future<Map<String, dynamic>> getSongList(String sortId, String? tagId, int page) {
    return KwSongList.getList(sortId, tagId, page);
  }

  /// 获取歌单详情
  static Future<Map<String, dynamic>> getSongListDetail(String id, int page) {
    return KwSongList.getListDetail(id, page);
  }

  /// 搜索歌单
  static Future<Map<String, dynamic>> searchSongList(String text, int page, {int limit = 20}) {
    return KwSongList.search(text, page, limit: limit);
  }

  /// 获取搜索提示
  static Future<List<String>> getTipSearch(String keyword) {
    return KwTipSearch.search(keyword);
  }

  /// 获取评论列表
  static Future<CommentResult> getComment({
    required String sid,
    required String digest,
    int page = 1,
    int limit = 20,
  }) {
    return KwComment.getComment(sid: sid, digest: digest, page: page, limit: limit);
  }
}
