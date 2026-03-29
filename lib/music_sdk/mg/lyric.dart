import 'dart:convert';
import '../../utils/http_client.dart';
import '../../models/lyric_info.dart';

/// 咪咕音乐歌词 — 对齐 LX Music mg/lyric.js
/// 支持 MRC/LRC/TRC 三种歌词格式
/// MRC 优先级最高 (逐字歌词)
class MgLyric {
  /// 获取歌词
  /// [songInfo] 包含 lrcUrl, mrcUrl, trcUrl 的歌曲信息
  static Future<LyricInfo> getLyric(Map<String, dynamic> songInfo) async {
    // 如果没有歌词URL，返回空
    if (songInfo['mrcUrl'] == null && songInfo['lrcUrl'] == null) {
      throw Exception('咪咕歌词URL为空');
    }

    String lyric = '';
    String lxlyric = '';

    // 优先获取MRC (逐字歌词)
    if (songInfo['mrcUrl'] != null) {
      try {
        final mrcText = await _getText(songInfo['mrcUrl']);
        if (mrcText.isNotEmpty) {
          final parsed = _parseMrc(mrcText);
          lyric = parsed['lyric'] ?? '';
          lxlyric = parsed['lxlyric'] ?? '';
        }
      } catch (_) {}
    }

    // 回退到LRC
    if (lyric.isEmpty && songInfo['lrcUrl'] != null) {
      try {
        lyric = await _getText(songInfo['lrcUrl']);
      } catch (_) {}
    }

    // 获取翻译
    String tlyric = '';
    if (songInfo['trcUrl'] != null) {
      try {
        tlyric = await _getText(songInfo['trcUrl']);
      } catch (_) {}
    }

    if (lyric.isEmpty) throw Exception('咪咕歌词获取失败');

    return LyricInfo(
      lyric: lyric,
      tlyric: tlyric.isNotEmpty ? tlyric : null,
      lxlyric: lxlyric.isNotEmpty ? lxlyric : null,
    );
  }

  /// 获取歌词文本
  static Future<String> _getText(String url) async {
    final resp = await HttpClient.get(url, headers: {
      'Referer': 'https://app.c.nf.migu.cn/',
      'User-Agent': 'Mozilla/5.0 (Linux; Android 5.1.1; Nexus 6 Build/LYZ28E) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Mobile Safari/537.36',
      'channel': '0146921',
    });

    if (resp.statusCode == 200) return resp.body;
    throw Exception('歌词获取失败: HTTP ${resp.statusCode}');
  }

  /// 解析 MRC 格式歌词 (逐字)
  static Map<String, String> _parseMrc(String str) {
    str = str.replaceAll('\r', '');
    final lines = str.split('\n');
    final lxlrcLines = <String>[];
    final lrcLines = <String>[];

    final lineTimeRegex = RegExp(r'^\s*\[(\d+),\d+\]');
    final wordTimeRegex = RegExp(r'\(\d+,\d+\)');
    final wordTimeAllRegex = RegExp(r'(\(\d+,\d+\))');

    for (final line in lines) {
      if (line.length < 6) continue;
      final result = lineTimeRegex.firstMatch(line);
      if (result == null) continue;

      final startTime = int.parse(result.group(1)!);
      var time = startTime;
      final ms = time % 1000;
      time ~/= 1000;
      final m = (time ~/ 60).toString().padLeft(2, '0');
      time %= 60;
      final s = time.toString().padLeft(2, '0');
      final timeStr = '[$m:$s.$ms]';

      final words = line.replaceFirst(lineTimeRegex, '');
      lrcLines.add('$timeStr${words.replaceAll(wordTimeAllRegex, '')}');

      final times = wordTimeAllRegex.allMatches(words).map((m) {
        final parts = RegExp(r'\((\d+),(\d+)\)').firstMatch(m.group(0)!)!;
        return '<${int.parse(parts.group(1)!) - startTime},${parts.group(2)}>';
      }).toList();

      if (times.isEmpty) continue;
      final wordArr = words.split(wordTimeRegex);
      final newWords = List.generate(
        times.length,
        (i) => '${times[i]}${i < wordArr.length ? wordArr[i] : ''}',
      ).join('');
      lxlrcLines.add('$timeStr$newWords');
    }

    return {
      'lyric': lrcLines.join('\n'),
      'lxlyric': lxlrcLines.join('\n'),
    };
  }
}
