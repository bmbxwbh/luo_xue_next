import 'dart:convert' show base64Decode;
import 'package:flutter/foundation.dart';
import '../../models/enums.dart';
import '../../models/song_model.dart';
import '../../models/lyric_info.dart';
import '../../utils/http_client.dart';
import '../../music_sdk/index.dart';
import '../../services/user_api/user_api_manager.dart';

/// 在线音乐服务 — 对齐 LX Music core/music/online.ts
/// 播放URL 通过 API 源获取，歌词/封面通过 MusicSdk 获取
class OnlineMusicService {
  /// API 基础地址（可配置）
  String _apiBase = 'https://lxmusicapi.onrender.com';

  /// 用户 API 管理器（可选）
  UserApiManager? _userApiManager;

  /// 设置API地址
  void setApiBase(String url) {
    _apiBase = url;
  }

  /// 设置用户 API 管理器
  void setUserApiManager(UserApiManager manager) {
    _userApiManager = manager;
  }

  // ============ 播放URL获取 — 对齐 apis(source).getMusicUrl() ============

  /// 获取音乐播放URL — 对齐 apis(source).getMusicUrl()
  /// 当用户API音源启用时，所有URL请求走用户API（全局覆盖）
  Future<String?> getMusicUrl({
    required SongModel musicInfo,
    required Quality quality,
    bool isRefresh = false,
  }) async {
    try {
      final source = musicInfo.source.id;
      final songmid = musicInfo.songmid;

      // 用户API音源启用时，全局覆盖URL获取 — 对齐 apis(source) 返回 userApi
      if (_userApiManager != null && _userApiManager!.isInitialized) {
        try {
          final url = await _userApiManager!.getMusicUrl(
            source: source,
            musicInfo: musicInfo.toMusicInfoJson(),
            quality: quality.value,
          );
          if (url != null && url.isNotEmpty) {
            debugPrint('[OnlineMusic] 播放URL来自用户API ✅ source=$source');
            return url;
          }
          debugPrint('[OnlineMusic] 用户API URL为空，回退内置源');
        } catch (e) {
          // 用户API获取失败，回退到内置源
          debugPrint('[OnlineMusic] 用户API获取URL失败: $e');
        }
      } else {
        debugPrint('[OnlineMusic] 用户API未初始化: manager=${_userApiManager != null}, inited=${_userApiManager?.isInitialized}');
      }

      // 酷我音乐
      if (source == 'kw') {
        return await _getKwMusicUrl(songmid, quality);
      }

      // 酷狗音乐
      if (source == 'kg') {
        return await _getKgMusicUrl(musicInfo, quality);
      }

      // QQ音乐
      if (source == 'tx') {
        return await _getTxMusicUrl(songmid, musicInfo.meta.strMediaMid, quality);
      }

      // 网易云音乐
      if (source == 'wy') {
        return await _getWyMusicUrl(songmid, quality);
      }

      // 咪咕音乐
      if (source == 'mg') {
        return await _getMgMusicUrl(musicInfo, quality);
      }

      // 通过通用API获取
      return await _getMusicUrlViaApi(source, songmid, quality.value);
    } catch (e) {
      print('getMusicUrl error: $e');
      return null;
    }
  }

  /// 酷我音乐播放链接
  Future<String?> _getKwMusicUrl(String songmid, Quality quality) async {
    final type = quality.value;
    final url = 'http://www.kuwo.cn/api/v1/www/music/playUrl?mid=$songmid&type=music&br=${_getKwBr(type)}';
    final resp = await HttpClient.get(url, headers: {
      'Referer': 'http://www.kuwo.cn/',
      'csrf': '',
    });
    if (resp.ok && resp.jsonBody is Map) {
      final data = resp.jsonBody as Map<String, dynamic>;
      if (data['code'] == 200 && data['data'] is Map) {
        return data['data']['url'] as String?;
      }
    }
    return null;
  }

  String _getKwBr(String type) {
    switch (type) {
      case '128k': return '128';
      case '192k': return '192';
      case '320k': return '320';
      case 'flac': return '2000';
      case 'flac24bit': return '4000';
      default: return '128';
    }
  }

  /// 酷狗音乐播放链接
  Future<String?> _getKgMusicUrl(SongModel musicInfo, Quality quality) async {
    final hash = musicInfo.meta.hash;
    if (hash == null || hash.isEmpty) return null;
    final albumId = musicInfo.meta.albumId ?? '';
    final url = 'https://wwwapi.kugou.com/yy/index.php?r=play/getdata&hash=$hash&mid=${DateTime.now().millisecondsSinceEpoch}&appid=1014&platid=4&album_id=$albumId';
    final resp = await HttpClient.get(url);
    if (resp.ok && resp.jsonBody is Map) {
      final data = resp.jsonBody as Map<String, dynamic>;
      if (data['data'] is Map) {
        final playUrl = data['data']['play_url'] as String?;
        if (playUrl != null && playUrl.isNotEmpty) return playUrl;
      }
    }
    return null;
  }

  /// QQ音乐播放链接
  Future<String?> _getTxMusicUrl(String songmid, String? mediaMid, Quality quality) async {
    final guid = '${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    final type = _getTxType(quality.value);
    final url = 'https://u.y.qq.com/cgi-bin/musicu.fcg?data={"req_0":{"module":"vkey.GetVkeyServer","method":"CgiGetVkey","param":{"guid":"$guid","songmid":["$songmid"],"songtype":[0],"uin":"0","loginflag":1,"platform":"20"}}}';
    final resp = await HttpClient.get(url);
    if (resp.ok && resp.jsonBody is Map) {
      final data = resp.jsonBody as Map<String, dynamic>;
      final req0 = data['req_0'];
      if (req0 is Map && req0['data'] is Map) {
        final midurlinfo = req0['data']['midurlinfo'];
        if (midurlinfo is List && midurlinfo.isNotEmpty) {
          final purl = midurlinfo[0]['purl'] as String?;
          if (purl != null && purl.isNotEmpty) {
            return 'https://dl.stream.qqmusic.qq.com/$purl';
          }
        }
      }
    }
    return null;
  }

  String _getTxType(String quality) {
    switch (quality) {
      case '128k': return 'M500';
      case '320k': return 'M800';
      case 'flac': return 'F000';
      default: return 'M500';
    }
  }

  /// 网易云音乐播放链接
  Future<String?> _getWyMusicUrl(String songmid, Quality quality) async {
    final br = _getWyBr(quality.value);
    final url = '$_apiBase/netease/url?id=$songmid&br=$br';
    final resp = await HttpClient.get(url);
    if (resp.ok && resp.jsonBody is Map) {
      final data = resp.jsonBody as Map<String, dynamic>;
      if (data['url'] != null) return data['url'] as String;
      if (data['data'] is List && (data['data'] as List).isNotEmpty) {
        return (data['data'] as List).first['url'] as String?;
      }
    }
    return null;
  }

  String _getWyBr(String quality) {
    switch (quality) {
      case '128k': return '128000';
      case '192k': return '192000';
      case '320k': return '320000';
      case 'flac': return '999000';
      default: return '320000';
    }
  }

  /// 咪咕音乐播放链接
  Future<String?> _getMgMusicUrl(SongModel musicInfo, Quality quality) async {
    final copyrightId = musicInfo.meta.copyrightId;
    if (copyrightId == null || copyrightId.isEmpty) return null;
    final br = _getMgBr(quality.value);
    // 尝试直接 API
    try {
      final url = 'https://app.c.nf.migu.cn/MIGUM2.0/v1.0/content/queryListenUrl.do?netType=01&resourceType=2&songId=$copyrightId&toneFlag=$br';
      final resp = await HttpClient.get(url, headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36',
        'Referer': 'http://music.migu.cn/',
      });
      if (resp.ok && resp.jsonBody is Map) {
        final data = resp.jsonBody as Map<String, dynamic>;
        final urlList = data['data']?['urlList'];
        if (urlList is List && urlList.isNotEmpty) {
          final playUrl = urlList[0]['playUrl'] as String?;
          if (playUrl != null && playUrl.isNotEmpty) {
            return playUrl.startsWith('http') ? playUrl : 'https:$playUrl';
          }
        }
      }
    } catch (_) {}
    // 回退代理
    try {
      final proxyUrl = '$_apiBase/migu/url?id=$copyrightId&quality=${quality.value}';
      final resp = await HttpClient.get(proxyUrl);
      if (resp.ok && resp.jsonBody is Map) {
        final data = resp.jsonBody as Map<String, dynamic>;
        if (data['url'] != null) return data['url'] as String;
      }
    } catch (_) {}
    return null;
  }

  String _getMgBr(String quality) {
    switch (quality) {
      case '128k': return '1';
      case '320k': return '2';
      case 'flac': return '3';
      default: return '2';
    }
  }

  /// 通过通用API获取播放链接
  Future<String?> _getMusicUrlViaApi(String source, String songmid, String quality) async {
    final url = '$_apiBase/$source/url?id=$songmid&quality=$quality';
    final resp = await HttpClient.get(url);
    if (resp.ok && resp.jsonBody is Map) {
      final data = resp.jsonBody as Map<String, dynamic>;
      return data['url'] as String?;
    }
    return null;
  }

  // ============ 封面获取 — 对齐 musicSdk[source].getPic() ============

  /// 获取封面路径 — 对齐 getPicPath
  /// 用户API启用时优先使用
  Future<String?> getPicPath(SongModel musicInfo) async {
    try {
      // 如果已有封面URL，直接返回
      if (musicInfo.meta.picUrl != null && musicInfo.meta.picUrl!.isNotEmpty) {
        return musicInfo.meta.picUrl;
      }

      // 用户API启用时优先尝试
      if (_userApiManager != null && _userApiManager!.isInitialized) {
        try {
          final url = await _userApiManager!.getPic(
            source: musicInfo.source.id,
            musicInfo: musicInfo.toMusicInfoJson(),
          );
          if (url.isNotEmpty) {
            debugPrint('[OnlineMusic] 封面来自用户API ✅ source=${musicInfo.source.id}');
            return url;
          }
          debugPrint('[OnlineMusic] 用户API封面为空，回退MusicSdk');
        } catch (e) {
          debugPrint('[OnlineMusic] 用户API获取封面失败: $e，回退MusicSdk');
        }
      }

      // 使用 MusicSdk 获取封面 — 对齐 musicSdk[source].getPic()
      try {
        final url = await MusicSdk.getPic(musicInfo.source, musicInfo.toMusicInfoJson());
        if (url != null && url.isNotEmpty) return url;
      } catch (_) {}

      return musicInfo.meta.picUrl;
    } catch (e) {
      print('getPicPath error: $e');
      return null;
    }
  }

  // ============ 歌词获取 — 对齐 musicSdk[source].getLyric() ============

  /// 获取歌词信息 — 对齐 getLyricInfo
  /// 用户API启用时优先使用
  Future<LyricInfo> getLyricInfo(SongModel musicInfo) async {
    try {
      // 用户API启用时优先尝试
      if (_userApiManager != null && _userApiManager!.isInitialized) {
        try {
          final lyricData = await _userApiManager!.getLyric(
            source: musicInfo.source.id,
            musicInfo: musicInfo.toMusicInfoJson(),
          );
          if (lyricData.isNotEmpty && (lyricData['lyric'] ?? '').toString().isNotEmpty) {
            debugPrint('[OnlineMusic] 歌词来自用户API ✅ source=${musicInfo.source.id}');
            return LyricInfo(
              lyric: lyricData['lyric'] ?? '',
              tlyric: lyricData['tlyric'],
            );
          }
          debugPrint('[OnlineMusic] 用户API歌词为空，回退MusicSdk');
        } catch (e) {
          debugPrint('[OnlineMusic] 用户API获取歌词失败: $e，回退MusicSdk');
        }
      }

      // 使用 MusicSdk 获取歌词 — 对齐 musicSdk[source].getLyric()
      try {
        final lyricData = await MusicSdk.getLyric(musicInfo.source, musicInfo.toMusicInfoJson());
        return LyricInfo(
          lyric: lyricData['lyric'] ?? '',
          tlyric: lyricData['tlyric'],
          rlyric: lyricData['rlyric'],
          lxlrc: lyricData['lxlrc'],
        );
      } catch (e) {
        print('MusicSdk getLyric error: $e');
        return const LyricInfo(lyric: '');
      }
    } catch (e) {
      print('getLyricInfo error: $e');
      return const LyricInfo(lyric: '');
    }
  }
}
