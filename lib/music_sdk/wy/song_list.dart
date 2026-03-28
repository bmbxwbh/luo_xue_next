import 'dart:convert';
import '../../utils/http_client.dart';
import '../../utils/eapi_encryptor.dart';
import '../../utils/format_util.dart';

/// 网易云音乐歌单 — 对齐 LX Music wy/songList.js
class WySongList {
  static const int limitList = 30;
  static const int successCode = 200;

  /// 排序列表
  static const List<Map<String, dynamic>> sortList = [
    {'name': '最热', 'tid': 'hot', 'id': 'hot'},
  ];

  /// 获取歌单推荐列表
  /// API: https://music.163.com/weapi/playlist/list
  static Future<Map<String, dynamic>> getList(String sortId, {String? tagId, int page = 1}) async {
    final form = EapiEncryptor.weapi({
      'cat': tagId ?? '全部',
      'order': sortId,
      'limit': limitList,
      'offset': limitList * (page - 1),
      'total': true,
    });

    final resp = await HttpClient.postForm(
      'https://music.163.com/weapi/playlist/list',
      headers: {
        'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36',
        'origin': 'https://music.163.com',
      },
      body: form,
    );

    if (resp.statusCode != 200 || resp.jsonBody == null) {
      throw Exception('获取网易云歌单列表失败');
    }

    final body = resp.jsonBody;
    if (body['code'] != successCode) {
      throw Exception('网易云歌单API错误');
    }

    final playlists = body['playlists'] as List? ?? [];
    return {
      'list': _filterList(playlists),
      'total': body['total'] ?? 0,
      'page': page,
      'limit': limitList,
      'source': 'wy',
    };
  }

  /// 获取歌单详情
  /// API: https://music.163.com/api/linux/forward → https://music.163.com/api/v3/playlist/detail
  static Future<Map<String, dynamic>> getListDetail(String id) async {
    final form = EapiEncryptor.linuxapi({
      'method': 'POST',
      'url': 'https://music.163.com/api/v3/playlist/detail',
      'params': {
        'id': id,
        'n': 100000,
        's': 8,
      },
    });

    final resp = await HttpClient.postForm(
      'https://music.163.com/api/linux/forward',
      headers: {
        'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36',
      },
      body: form,
    );

    if (resp.statusCode != 200 || resp.jsonBody == null) {
      throw Exception('获取网易云歌单详情失败');
    }

    final body = resp.jsonBody;
    if (body['code'] != successCode) {
      throw Exception('网易云歌单详情API错误');
    }

    final playlist = body['playlist'] ?? {};
    final tracks = playlist['tracks'] as List? ?? [];
    final privileges = body['privileges'] as List? ?? [];

    return {
      'list': _filterListDetail(tracks, privileges),
      'page': 1,
      'limit': 1000,
      'total': (playlist['trackIds'] as List?)?.length ?? tracks.length,
      'source': 'wy',
      'info': {
        'play_count': formatPlayCount(playlist['playCount']),
        'name': playlist['name'] ?? '',
        'img': playlist['coverImgUrl'],
        'desc': playlist['description'],
        'author': playlist['creator']?['nickname'],
      },
    };
  }

  /// 搜索歌单
  /// API: https://interface3.music.163.com/eapi/cloudsearch/pc
  static Future<Map<String, dynamic>> search(String text, {int page = 1, int limit = 20}) async {
    final data = {
      's': text,
      'type': 1000, // 歌单类型
      'limit': limit,
      'total': page == 1,
      'offset': limit * (page - 1),
    };

    final form = EapiEncryptor.eapi('/api/cloudsearch/pc', data);

    final resp = await HttpClient.postForm(
      'https://interface3.music.163.com/eapi/cloudsearch/pc',
      headers: {
        'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36',
        'origin': 'https://music.163.com',
      },
      body: form,
    );

    if (resp.statusCode != 200 || resp.jsonBody == null) {
      throw Exception('搜索网易云歌单失败');
    }

    final body = resp.jsonBody;
    if (body['code'] != successCode) throw Exception('网易云歌单搜索API错误');

    return {
      'list': _filterList(body['result']?['playlists'] as List? ?? []),
      'limit': limit,
      'total': body['result']?['playlistCount'] ?? 0,
      'source': 'wy',
    };
  }

  /// 过滤歌单列表
  static List<Map<String, dynamic>> _filterList(List rawList) {
    return rawList.map<Map<String, dynamic>>((item) => {
      'play_count': formatPlayCount(item['playCount']),
      'id': item['id']?.toString() ?? '',
      'author': item['creator']?['nickname'] ?? '',
      'name': item['name'] ?? '',
      'img': item['coverImgUrl'],
      'total': item['trackCount'],
      'desc': item['description'],
      'source': 'wy',
    }).toList();
  }

  /// 过滤歌单详情歌曲列表
  static List<Map<String, dynamic>> _filterListDetail(List tracks, List privileges) {
    final list = <Map<String, dynamic>>[];

    for (var i = 0; i < tracks.length; i++) {
      final item = tracks[i];
      final types = <Map<String, String>>[];
      final typesMap = <String, Map<String, String>>{};

      // 查找对应的privilege
      Map<String, dynamic>? privilege;
      if (i < privileges.length && privileges[i]['id'] == item['id']) {
        privilege = privileges[i];
      } else {
        privilege = privileges.cast<Map<String, dynamic>?>().firstWhere(
          (p) => p?['id'] == item['id'],
          orElse: () => null,
        );
      }
      if (privilege == null) continue;

      if (privilege['maxBrLevel'] == 'hires') {
        final size = item['hr'] != null ? sizeFormate(item['hr']['size']) : null;
        types.add({'type': 'flac24bit', 'size': size ?? ''});
        typesMap['flac24bit'] = {'size': size ?? ''};
      }

      final maxbr = privilege['maxbr'] ?? 0;
      if (maxbr >= 999000) {
        types.add({'type': 'flac', 'size': ''});
        typesMap['flac'] = {'size': ''};
      }
      if (maxbr >= 320000) {
        final size = item['h'] != null ? sizeFormate(item['h']['size']) : null;
        types.add({'type': '320k', 'size': size ?? ''});
        typesMap['320k'] = {'size': size ?? ''};
      }
      if (maxbr >= 128000) {
        final size = item['l'] != null ? sizeFormate(item['l']['size']) : null;
        types.add({'type': '128k', 'size': size ?? ''});
        typesMap['128k'] = {'size': size ?? ''};
      }

      types.reversed.toList();

      final ar = item['ar'] as List? ?? [];
      final al = item['al'] ?? {};

      // 支持pc字段 (降级格式)
      if (item['pc'] != null) {
        list.add({
          'singer': item['pc']['ar'] ?? '',
          'name': item['pc']['sn'] ?? '',
          'albumName': item['pc']['alb'] ?? '',
          'albumId': al['id'],
          'source': 'wy',
          'interval': formatPlayTime((item['dt'] ?? 0) / 1000),
          'songmid': item['id'],
          'img': al['picUrl'] ?? '',
          'lrc': null,
          'otherSource': null,
          'types': types,
          '_types': typesMap,
          'typeUrl': {},
        });
      } else {
        list.add({
          'singer': formatSingerName(ar),
          'name': item['name'] ?? '',
          'albumName': al['name'],
          'albumId': al['id'],
          'source': 'wy',
          'interval': formatPlayTime((item['dt'] ?? 0) / 1000),
          'songmid': item['id'],
          'img': al['picUrl'],
          'lrc': null,
          'otherSource': null,
          'types': types,
          '_types': typesMap,
          'typeUrl': {},
        });
      }
    }

    return list;
  }
}
