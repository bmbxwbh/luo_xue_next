import 'dart:convert';
import '../../utils/http_client.dart';
import '../../utils/format_util.dart';

/// QQ音乐排行榜 — 对齐 LX Music tx/leaderboard.js
/// API: POST https://u.y.qq.com/cgi-bin/musicu.fcg
class TxLeaderboard {
  /// 预设榜单列表
  static const List<Map<String, dynamic>> boardList = [
    {'id': 'tx__4', 'name': '流行指数榜', 'bangid': '4'},
    {'id': 'tx__26', 'name': '热歌榜', 'bangid': '26'},
    {'id': 'tx__27', 'name': '新歌榜', 'bangid': '27'},
    {'id': 'tx__62', 'name': '飙升榜', 'bangid': '62'},
    {'id': 'tx__58', 'name': '说唱榜', 'bangid': '58'},
    {'id': 'tx__57', 'name': '喜力电音榜', 'bangid': '57'},
    {'id': 'tx__28', 'name': '网络歌曲榜', 'bangid': '28'},
    {'id': 'tx__5', 'name': '内地榜', 'bangid': '5'},
    {'id': 'tx__3', 'name': '欧美榜', 'bangid': '3'},
    {'id': 'tx__59', 'name': '香港地区榜', 'bangid': '59'},
    {'id': 'tx__16', 'name': '韩国榜', 'bangid': '16'},
    {'id': 'tx__60', 'name': '抖快榜', 'bangid': '60'},
    {'id': 'tx__29', 'name': '影视金曲榜', 'bangid': '29'},
    {'id': 'tx__17', 'name': '日本榜', 'bangid': '17'},
    {'id': 'tx__52', 'name': '腾讯音乐人原创榜', 'bangid': '52'},
    {'id': 'tx__36', 'name': 'K歌金曲榜', 'bangid': '36'},
    {'id': 'tx__61', 'name': '台湾地区榜', 'bangid': '61'},
    {'id': 'tx__63', 'name': 'DJ舞曲榜', 'bangid': '63'},
    {'id': 'tx__64', 'name': '综艺新歌榜', 'bangid': '64'},
    {'id': 'tx__65', 'name': '国风热歌榜', 'bangid': '65'},
    {'id': 'tx__67', 'name': '听歌识曲榜', 'bangid': '67'},
    {'id': 'tx__72', 'name': '动漫音乐榜', 'bangid': '72'},
    {'id': 'tx__73', 'name': '游戏音乐榜', 'bangid': '73'},
    {'id': 'tx__75', 'name': '有声榜', 'bangid': '75'},
    {'id': 'tx__131', 'name': '校园音乐人排行榜', 'bangid': '131'},
  ];

  /// 简化版榜单（UI展示用）
  static const List<Map<String, dynamic>> shortList = [
    {'id': 'txlxzsb', 'name': '流行榜', 'bangid': 4},
    {'id': 'txrgb', 'name': '热歌榜', 'bangid': 26},
    {'id': 'txwlhgb', 'name': '网络榜', 'bangid': 28},
    {'id': 'txdyb', 'name': '抖音榜', 'bangid': 60},
    {'id': 'txndb', 'name': '内地榜', 'bangid': 5},
    {'id': 'txxgb', 'name': '香港榜', 'bangid': 59},
    {'id': 'txtwb', 'name': '台湾榜', 'bangid': 61},
    {'id': 'txoumb', 'name': '欧美榜', 'bangid': 3},
    {'id': 'txhgb', 'name': '韩国榜', 'bangid': 16},
    {'id': 'txrbb', 'name': '日本榜', 'bangid': 17},
    {'id': 'txtybb', 'name': 'YouTube榜', 'bangid': 128},
  ];

  /// 获取榜单列表
  static Future<List<Map<String, dynamic>>> getBoards() async {
    return boardList;
  }

  /// 获取榜单详情
  /// API: POST https://u.y.qq.com/cgi-bin/musicu.fcg
  static Future<Map<String, dynamic>> getList(int bangId, String period) async {
    final body = {
      'toplist': {
        'module': 'musicToplist.ToplistInfoServer',
        'method': 'GetDetail',
        'param': {
          'topid': bangId,
          'num': 300,
          'period': period,
        },
      },
      'comm': {
        'uin': 0,
        'format': 'json',
        'ct': 20,
        'cv': 1859,
      },
    };

    final resp = await HttpClient.post(
      'https://u.y.qq.com/cgi-bin/musicu.fcg',
      headers: {'User-Agent': 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0)'},
      body: jsonEncode(body),
    );

    if (resp.statusCode != 200 || resp.jsonBody == null) {
      throw Exception('获取QQ音乐排行榜失败');
    }

    final json = resp.jsonBody;
    if (json['code'] != 0) {
      throw Exception('QQ音乐排行榜API错误');
    }

    final songInfoList = json['toplist']?['data']?['songInfoList'] as List? ?? [];
    final list = _filterData(songInfoList);

    return {
      'total': list.length,
      'list': list,
      'limit': 300,
      'page': 1,
      'source': 'tx',
    };
  }

  /// 过滤榜单数据
  static List<Map<String, dynamic>> _filterData(List rawList) {
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
