import 'dart:convert';
import '../../utils/http_client.dart';
import '../../utils/format_util.dart';

/// QQ音乐歌单 — 对齐 LX Music tx/songList.js
class TxSongList {
  static const int limitList = 36;
  static const int successCode = 0;

  /// 排序列表
  static const List<Map<String, dynamic>> sortList = [
    {'name': '最热', 'tid': 'hot', 'id': 5},
    {'name': '最新', 'tid': 'new', 'id': 2},
  ];

  /// 获取歌单推荐列表
  /// API: GET https://u.y.qq.com/cgi-bin/musicu.fcg (with encoded data param)
  static Future<Map<String, dynamic>> getList(int sortId, {String? tagId, int page = 1}) async {
    String url;
    if (tagId != null) {
      final id = int.tryParse(tagId) ?? 0;
      final data = {
        'comm': {'cv': 1602, 'ct': 20},
        'playlist': {
          'method': 'get_category_content',
          'param': {
            'titleid': id,
            'caller': '0',
            'category_id': id,
            'size': limitList,
            'page': page - 1,
            'use_page': 1,
          },
          'module': 'playlist.PlayListCategoryServer',
        },
      };
      url = 'https://u.y.qq.com/cgi-bin/musicu.fcg?loginUin=0&hostUin=0&format=json&inCharset=utf-8&outCharset=utf-8&notice=0&platform=wk_v15.json&needNewCode=0&data=${Uri.encodeComponent(jsonEncode(data))}';
    } else {
      final data = {
        'comm': {'cv': 1602, 'ct': 20},
        'playlist': {
          'method': 'get_playlist_by_tag',
          'param': {
            'id': 10000000,
            'sin': limitList * (page - 1),
            'size': limitList,
            'order': sortId,
            'cur_page': page,
          },
          'module': 'playlist.PlayListPlazaServer',
        },
      };
      url = 'https://u.y.qq.com/cgi-bin/musicu.fcg?loginUin=0&hostUin=0&format=json&inCharset=utf-8&outCharset=utf-8&notice=0&platform=wk_v15.json&needNewCode=0&data=${Uri.encodeComponent(jsonEncode(data))}';
    }

    final resp = await HttpClient.get(url);
    if (resp.statusCode != 200 || resp.jsonBody == null) {
      throw Exception('获取QQ音乐歌单列表失败');
    }

    final body = resp.jsonBody;
    if (body['code'] != successCode) {
      throw Exception('QQ音乐歌单API错误');
    }

    final playlistData = body['playlist']?['data'];
    if (tagId != null) {
      return _filterList2(playlistData, page);
    }
    return _filterList(playlistData, page);
  }

  /// 获取歌单详情
  /// API: GET https://c.y.qq.com/qzone/fcg-bin/fcg_ucc_getcdinfo_byids_cp.fcg
  static Future<Map<String, dynamic>> getListDetail(String id) async {
    final url = 'https://c.y.qq.com/qzone/fcg-bin/fcg_ucc_getcdinfo_byids_cp.fcg?type=1&json=1&utf8=1&onlysong=0&new_format=1&disstid=$id&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8&notice=0&platform=yqq.json&needNewCode=0';

    final resp = await HttpClient.get(url, headers: {
      'Origin': 'https://y.qq.com',
      'Referer': 'https://y.qq.com/n/yqq/playsquare/$id.html',
    });

    if (resp.statusCode != 200 || resp.jsonBody == null) {
      throw Exception('获取QQ音乐歌单详情失败');
    }

    final body = resp.jsonBody;
    if (body['code'] != successCode) {
      throw Exception('QQ音乐歌单详情API错误');
    }

    final cdlist = body['cdlist'][0];
    final songlist = cdlist['songlist'] as List? ?? [];

    return {
      'list': _filterListDetail(songlist),
      'page': 1,
      'limit': songlist.length + 1,
      'total': songlist.length,
      'source': 'tx',
      'info': {
        'name': cdlist['dissname'],
        'img': cdlist['logo'],
        'desc': (cdlist['desc'] ?? '').toString().replaceAll('<br>', '\n'),
        'author': cdlist['nickname'],
        'play_count': formatPlayCount(cdlist['visitnum']),
      },
    };
  }

  /// 搜索歌单
  /// API: GET http://c.y.qq.com/soso/fcgi-bin/client_music_search_songlist
  static Future<Map<String, dynamic>> search(String text, {int page = 1, int limit = 20}) async {
    final url = 'http://c.y.qq.com/soso/fcgi-bin/client_music_search_songlist?page_no=${page - 1}&num_per_page=$limit&format=json&query=${Uri.encodeComponent(text)}&remoteplace=txt.yqq.playlist&inCharset=utf8&outCharset=utf-8';

    final resp = await HttpClient.get(url, headers: {
      'User-Agent': 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0)',
      'Referer': 'http://y.qq.com/portal/search.html',
    });

    if (resp.statusCode != 200 || resp.jsonBody == null) {
      throw Exception('搜索QQ音乐歌单失败');
    }

    final body = resp.jsonBody;
    if (body['code'] != 0) throw Exception('QQ音乐歌单搜索API错误');

    final list = (body['data']?['list'] as List? ?? []).map((item) => {
      'play_count': formatPlayCount(item['listennum']),
      'id': item['dissid']?.toString() ?? '',
      'author': item['creator']?['name'] ?? '',
      'name': item['dissname'] ?? '',
      'img': item['imgurl'],
      'total': item['song_count'],
      'desc': (item['introduction'] ?? '').toString().replaceAll('<br>', '\n'),
      'source': 'tx',
    }).toList();

    return {
      'list': list,
      'limit': limit,
      'total': body['data']?['sum'] ?? 0,
      'source': 'tx',
    };
  }

  /// 过滤歌单列表 (推荐)
  static Map<String, dynamic> _filterList(dynamic data, int page) {
    final vPlaylist = data?['v_playlist'] as List? ?? [];
    return {
      'list': vPlaylist.map((item) => {
        'play_count': formatPlayCount(item['access_num']),
        'id': item['tid']?.toString() ?? '',
        'author': item['creator_info']?['nick'] ?? '',
        'name': item['title'] ?? '',
        'img': item['cover_url_medium'],
        'total': (item['song_ids'] as List?)?.length ?? 0,
        'desc': (item['desc'] ?? '').toString().replaceAll('<br>', '\n'),
        'source': 'tx',
      }).toList(),
      'total': data?['total'] ?? 0,
      'page': page,
      'limit': limitList,
      'source': 'tx',
    };
  }

  /// 过滤歌单列表 (分类)
  static Map<String, dynamic> _filterList2(dynamic data, int page) {
    final content = data?['content'];
    final vItem = content?['v_item'] as List? ?? [];
    return {
      'list': vItem.map((item) {
        final basic = item['basic'] ?? {};
        return {
          'play_count': formatPlayCount(basic['play_cnt']),
          'id': basic['tid']?.toString() ?? '',
          'author': basic['creator']?['nick'] ?? '',
          'name': basic['title'] ?? '',
          'img': basic['cover']?['medium_url'] ?? basic['cover']?['default_url'] ?? '',
          'desc': (basic['desc'] ?? '').toString().replaceAll('<br>', '\n'),
          'source': 'tx',
        };
      }).toList(),
      'total': content?['total_cnt'] ?? 0,
      'page': page,
      'limit': limitList,
      'source': 'tx',
    };
  }

  /// 过滤歌单详情歌曲列表
  static List<Map<String, dynamic>> _filterListDetail(List rawList) {
    return rawList.map<Map<String, dynamic>>((item) {
      final file = item['file'] ?? {};
      final types = <Map<String, String>>[];
      final typesMap = <String, Map<String, String>>{};

      if ((file['size_128mp3'] ?? 0) != 0) {
        final size = sizeFormate(file['size_128mp3']);
        types.add({'type': '128k', 'size': size});
        typesMap['128k'] = {'size': size};
      }
      if ((file['size_320mp3'] ?? 0) != 0) {
        final size = sizeFormate(file['size_320mp3']);
        types.add({'type': '320k', 'size': size});
        typesMap['320k'] = {'size': size};
      }
      if ((file['size_flac'] ?? 0) != 0) {
        final size = sizeFormate(file['size_flac']);
        types.add({'type': 'flac', 'size': size});
        typesMap['flac'] = {'size': size};
      }
      if ((file['size_hires'] ?? 0) != 0) {
        final size = sizeFormate(file['size_hires']);
        types.add({'type': 'flac24bit', 'size': size});
        typesMap['flac24bit'] = {'size': size};
      }

      final singers = item['singer'] as List? ?? [];
      final album = item['album'] ?? {};
      final albumMid = album['mid'] ?? '';

      String img = '';
      if (album['name'] == '' || album['name'] == '空') {
        if (singers.isNotEmpty) {
          img = 'https://y.gtimg.cn/music/photo_new/T001R500x500M000${singers[0]['mid']}.jpg';
        }
      } else {
        img = 'https://y.gtimg.cn/music/photo_new/T002R500x500M000$albumMid.jpg';
      }

      return {
        'singer': formatSingerName(singers),
        'name': item['title'] ?? '',
        'albumName': album['name'] ?? '',
        'albumId': albumMid,
        'source': 'tx',
        'interval': formatPlayTime(item['interval']),
        'songId': item['id'],
        'albumMid': albumMid,
        'strMediaMid': file['media_mid'],
        'songmid': item['mid'],
        'img': img,
        'lrc': null,
        'otherSource': null,
        'types': types,
        '_types': typesMap,
        'typeUrl': {},
      };
    }).toList();
  }
}
