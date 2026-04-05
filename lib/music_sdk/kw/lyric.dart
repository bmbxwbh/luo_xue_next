/// 酷我音乐歌词 — 对齐 LX Music kw/lyric.js
import 'dart:convert';
import 'dart:typed_data';
import '../../utils/http_client.dart';
import '../../utils/format_util.dart';

class KwLyric {
  static final _timeExp = RegExp(r'^\[([\d:.]*)\]{1}');
  static final _tagLineExp = RegExp(r'\[(ver|ti|ar|al|offset|by|kuwo):\s*(\S+(?:\s+\S+)*)\s*\]');
  static final _wordTimeAllExp = RegExp(r'<(-?\d+),(-?\d+)(?:,-?\d+)?>');
  static final _lyricxTagExp = RegExp(r'^<-?\d+,-?\d+>');
  static final _existTimeExp = RegExp(r'\[\d{1,2}:.*\d{1,4}\]');

  /// 构建加密参数 (XOR with "yeelion")
  static String _buildParams(String id, bool isGetLyricx) {
    final bufKey = utf8.encode('yeelion');
    var params = 'user=12345,web,web,web&requester=localhost&req=1&rid=MUSIC_$id';
    if (isGetLyricx) params += '&lrcx=1';
    final bufStr = utf8.encode(params);
    final output = Uint8List(bufStr.length);
    int i = 0;
    while (i < bufStr.length) {
      int j = 0;
      while (j < bufKey.length && i < bufStr.length) {
        output[i] = bufStr[i] ^ bufKey[j];
        i++;
        j++;
      }
    }
    return base64Encode(output);
  }

  /// 解析歌词行
  static Map<String, dynamic> _parseLrc(String lrc) {
    final lines = lrc.split(RegExp(r'\r\n|\r|\n'));
    final tags = <String>[];
    final lrcArr = <Map<String, String>>[];

    for (final line in lines) {
      final trimmed = line.trim();
      final result = _timeExp.firstMatch(trimmed);
      if (result != null) {
        final text = trimmed.replaceFirst(_timeExp, '').trim();
        var time = result.group(1)!;
        if (RegExp(r'\.\d\d$').hasMatch(time)) time += '0';
        lrcArr.add({'time': time, 'text': text});
      } else if (_tagLineExp.hasMatch(trimmed)) {
        tags.add(trimmed);
      }
    }

    final lrcInfo = _sortLrcArr(lrcArr);
    return {
      'lyric': decodeName('${tags.join('\n')}\n${lrcInfo['lrc']}'),
      'tlyric': (lrcInfo['lrcT'] as String).isNotEmpty
          ? decodeName('${tags.join('\n')}\n${lrcInfo['lrcT']}')
          : '',
    };
  }

  /// 分离原文和翻译歌词
  static Map<String, dynamic> _sortLrcArr(List<Map<String, String>> arr) {
    final lrcSet = <String>{};
    final lrc = <Map<String, String>>[];
    final lrcT = <Map<String, String>>[];

    bool isLyricx = false;
    for (final item in arr) {
      if (lrcSet.contains(item['time'])) {
        if (lrc.length < 2) continue;
        final tItem = lrc.removeLast();
        tItem['time'] = lrc.last['time']!;
        lrcT.add(tItem);
        lrc.add(item);
      } else {
        lrc.add(item);
        lrcSet.add(item['time']!);
      }
      if (!isLyricx && _lyricxTagExp.hasMatch(item['text'] ?? '')) isLyricx = true;
    }

    if (!isLyricx && lrcT.length > lrc.length * 0.3 && lrc.length - lrcT.length > 6) {
      throw Exception('failed');
    }

    return {
      'lrc': lrc.map((l) => '[${l['time']}]${l['text']}\n').join(''),
      'lrcT': lrcT.map((l) => '[${l['time']}]${l['text']}\n').join(''),
    };
  }

  /// 获取歌词
  static Future<Map<String, dynamic>> getLyric(Map<String, dynamic> musicInfo, {bool isGetLyricx = true}) async {
    final songmid = musicInfo['songmid']?.toString() ?? '';

    try {
      final resp = await HttpClient.get(
        'http://newlyric.kuwo.cn/newlyric.lrc?${_buildParams(songmid, isGetLyricx)}',
        headers: {'Accept': '*/*'},
        timeout: const Duration(seconds: 20),
      );

      if (resp.statusCode != 200) throw Exception('获取歌词失败');

      // 解析返回的歌词数据
      // 注意：完整实现需要 pako inflate + XOR 解密
      // 这里提供基础框架，完整解密需要平台原生支持
      final body = resp.body;
      if (!body.startsWith('tp=content')) throw Exception('Get lyric failed');

      // 找到内容部分
      final headerEnd = body.indexOf('\r\n\r\n');
      if (headerEnd < 0) throw Exception('Get lyric failed');

      // TODO: 需要 inflate 解压 + XOR 解密 (需要原生模块支持)
      // 这里返回一个标记，表示需要原生解密
      return {
        'lyric': '',
        'tlyric': '',
        'lxlyric': '',
        'raw': body,
        'needDecode': true,
        'isGetLyricx': isGetLyricx,
      };
    } catch (e) {
      throw Exception('Get lyric failed: $e');
    }
  }

  /// 解析已解密的歌词文本
  static Map<String, dynamic> parseDecryptedLrc(String lrcText) {
    final lrcInfo = _parseLrc(lrcText);
    var tlyric = lrcInfo['tlyric'] as String;
    if (tlyric.isNotEmpty) {
      tlyric = tlyric.replaceAll(_wordTimeAllExp, '');
    }
    return {
      'lyric': (lrcInfo['lyric'] as String).replaceAll(_wordTimeAllExp, ''),
      'tlyric': tlyric,
      'lxlyric': '',
    };
  }
}
