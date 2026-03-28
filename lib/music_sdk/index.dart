/// 音乐 SDK 总入口
/// 导入所有音乐源 SDK
import '../models/enums.dart';
import 'kg/index.dart';
import 'kw/index.dart';
import 'tx/index.dart';
import 'wy/index.dart';
import 'mg/index.dart';

/// 音乐 SDK 统一入口
class MusicSdk {
  /// 根据音源获取对应的 SDK 实例
  static dynamic getSource(MusicSource source) {
    switch (source) {
      case MusicSource.kg:
        return KgSdk;
      case MusicSource.kw:
        return KwSdk;
      case MusicSource.tx:
        return TxSdk;
      case MusicSource.wy:
        return WySdk;
      case MusicSource.local:
        throw UnsupportedError("本地音乐不支持此操作");
      case MusicSource.mg:
        return MgSdk;
    }
  }

  /// 搜索音乐 (统一接口)
  static Future<dynamic> search(MusicSource source, String keyword, {int page = 1, int limit = 30}) {
    switch (source) {
      case MusicSource.kg:
        return KgSdk.search(keyword, page: page, limit: limit);
      case MusicSource.kw:
        return KwSdk.search(keyword, page: page, limit: limit);
      case MusicSource.tx:
        return TxSdk.search(keyword, page: page, limit: limit);
      case MusicSource.wy:
        return WySdk.search(keyword, page: page, limit: limit);
      case MusicSource.local:
        throw UnsupportedError("本地音乐不支持此操作");
      case MusicSource.mg:
        return MgSdk.search(keyword, page: page, limit: limit);
    }
  }

  /// 获取歌词 (统一接口)
  static Future<Map<String, dynamic>> getLyric(MusicSource source, Map<String, dynamic> songInfo) {
    switch (source) {
      case MusicSource.kg:
        return KgSdk.getLyric(songInfo);
      case MusicSource.kw:
        return KwSdk.getLyric(songInfo);
      case MusicSource.tx:
        return TxSdk.getLyric(songInfo);
      case MusicSource.wy:
        return WySdk.getLyric(songInfo);
      case MusicSource.local:
        throw UnsupportedError("本地音乐不支持此操作");
      case MusicSource.mg:
        return MgSdk.getLyric(songInfo);
    }
  }

  /// 获取封面 (统一接口)
  static Future<String?> getPic(MusicSource source, Map<String, dynamic> songInfo) {
    switch (source) {
      case MusicSource.kg:
        return KgSdk.getPic(songInfo);
      case MusicSource.kw:
        return KwSdk.getPic(songInfo);
      case MusicSource.tx:
        return TxSdk.getPic(songInfo);
      case MusicSource.wy:
        return WySdk.getPic(songInfo);
      case MusicSource.local:
        throw UnsupportedError("本地音乐不支持此操作");
      case MusicSource.mg:
        return MgSdk.getPic(songInfo);
    }
  }

  /// 获取热搜 (统一接口)
  static Future<List<String>> getHotSearch(MusicSource source) {
    switch (source) {
      case MusicSource.kg:
        return KgSdk.getHotSearch();
      case MusicSource.kw:
        return KwSdk.getHotSearch();
      case MusicSource.tx:
        return TxSdk.getHotSearch();
      case MusicSource.wy:
        return WySdk.getHotSearch();
      case MusicSource.local:
        throw UnsupportedError("本地音乐不支持此操作");
      case MusicSource.mg:
        return MgSdk.getHotSearch();
    }
  }

  /// 获取排行榜列表 (统一接口)
  static Future<List> getBoards(MusicSource source) {
    switch (source) {
      case MusicSource.kg:
        return KgSdk.getBoards();
      case MusicSource.kw:
        return KwSdk.getBoards();
      case MusicSource.tx:
        return TxSdk.getBoards();
      case MusicSource.wy:
        return WySdk.getBoards();
      case MusicSource.local:
        throw UnsupportedError("本地音乐不支持此操作");
      case MusicSource.mg:
        return MgSdk.getBoards();
    }
  }

  /// 获取排行榜数据 (统一接口)
  static Future<Map<String, dynamic>> getLeaderboardList(MusicSource source, String bangid, int page) {
    switch (source) {
      case MusicSource.kg:
        return KgSdk.getLeaderboardList(bangid, page);
      case MusicSource.kw:
        return KwSdk.getLeaderboardList(bangid, page);
      case MusicSource.tx:
        return TxSdk.getLeaderboardList(bangid, page);
      case MusicSource.wy:
        return WySdk.getLeaderboardList(bangid, page);
      case MusicSource.local:
        throw UnsupportedError("本地音乐不支持此操作");
      case MusicSource.mg:
        return MgSdk.getLeaderboardList(bangid, page);
    }
  }

  /// 获取搜索提示 (统一接口)
  static Future<List<String>> getTipSearch(MusicSource source, String keyword) {
    switch (source) {
      case MusicSource.kg:
        return KgSdk.getTipSearch(keyword);
      case MusicSource.kw:
        return KwSdk.getTipSearch(keyword);
      case MusicSource.tx:
        return TxSdk.getTipSearch(keyword);
      case MusicSource.wy:
        return WySdk.getTipSearch(keyword);
      case MusicSource.local:
        throw UnsupportedError("本地音乐不支持此操作");
      case MusicSource.mg:
        return MgSdk.getTipSearch(keyword);
    }
  }
}
