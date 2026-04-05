import '../../utils/http_client.dart';
import '../../utils/eapi_encryptor.dart';
import '../../models/lyric_info.dart';

/// 网易云音乐歌词 — 对齐 LX Music wy/lyric.js
/// EAPI: https://interface3.music.163.com/eapi/song/lyric/v1
class WyLyric {
  /// 获取歌词 (支持逐字歌词、翻译、罗马音)
  static Future<LyricInfo> getLyric(dynamic songmid) async {
    final data = {
      'id': songmid,
      'cp': false,
      'tv': 0,
      'lv': 0,
      'rv': 0,
      'kv': 0,
      'yv': 0,
      'ytv': 0,
      'yrv': 0,
    };

    final form = EapiEncryptor.eapi('/eapi/song/lyric/v1', data);

    final resp = await HttpClient.postForm(
      'https://interface3.music.163.com/eapi/song/lyric/v1',
      headers: {
        'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36',
        'origin': 'https://music.163.com',
      },
      body: form,
    );

    if (resp.statusCode != 200 || resp.jsonBody == null) {
      throw Exception('获取网易云歌词失败');
    }

    final body = resp.jsonBody;
    if (body['code'] != 200 || body['lrc']?['lyric'] == null) {
      throw Exception('网易云歌词为空');
    }

    // 修复时间标签格式
    final lrc = _fixTimeLabel(body['lrc']?['lyric']);
    final tlrc = _fixTimeLabel(body['tlyric']?['lyric']);
    final romalrc = _fixTimeLabel(body['romalrc']?['yric']);

    // 优先使用逐字歌词 (yrc)
    String lxlyric = '';
    String lyric = lrc ?? '';
    String tlyric = tlrc ?? '';
    String rlyric = romalrc ?? '';

    if (body['yrc']?['lyric'] != null) {
      final parsed = _parseYrc(body['yrc']['lyric'], body['ytlrc']?['lyric'], body['yromalrc']?['lyric']);
      if (parsed != null) {
        lyric = parsed['lyric'] ?? lyric;
        tlyric = parsed['tlyric'] ?? tlyric;
        rlyric = parsed['rlyric'] ?? rlyric;
        lxlyric = parsed['lxlyric'] ?? '';
      }
    }

    if (lyric.isEmpty) throw Exception('网易云歌词为空');

    return LyricInfo(
      lyric: lyric,
      tlyric: tlyric.isNotEmpty ? tlyric : null,
      rlyric: rlyric.isNotEmpty ? rlyric : null,
      lxlyric: lxlyric.isNotEmpty ? lxlyric : null,
    );
  }

  /// 修复时间标签格式 [mm:ss:xx] → [mm:ss.xx]
  static String? _fixTimeLabel(String? lrc) {
    if (lrc == null) return null;
    return lrc.replaceAllMapped(
      RegExp(r'\[(\d{2}:\d{2}):(\d{2})]'),
      (m) => '[${m[1]}.${m[2]}]',
    );
  }

  /// 解析逐字歌词
  static Map<String, String>? _parseYrc(String? ylrc, String? ytlrc, String? yrlrc) {
    if (ylrc == null || ylrc.isEmpty) return null;

    final lines = ylrc.replaceAll('\r', '').split('\n');
    final lxlrcLines = <String>[];
    final lrcLines = <String>[];

    final lineTimeRegex = RegExp(r'^\[(\d+),\d+\]');
    final wordTimeRegex = RegExp(r'\(\d+,\d+,\d+\)');

    for (final line in lines) {
      final result = lineTimeRegex.firstMatch(line);
      if (result == null) continue;

      final startMs = int.tryParse(result.group(1) ?? '') ?? 0;
      final timeStr = _msFormat(startMs);
      if (timeStr.isEmpty) continue;

      final words = line.replaceFirst(lineTimeRegex, '');
      lrcLines.add('$timeStr${words.replaceAll(wordTimeRegex, '')}');

      final times = wordTimeRegex.allMatches(words).map((m) {
        final parts = RegExp(r'\((\d+),(\d+),\d+\)').firstMatch(m.group(0)!)!;
        final offset = int.parse(parts.group(1)!) - startMs;
        return '<${offset > 0 ? offset : 0},${parts.group(2)}>';
      }).toList();

      final wordArr = words.split(wordTimeRegex);
      if (wordArr.isNotEmpty) wordArr.removeAt(0);
      final newWords = List.generate(
        times.length,
        (i) => '${times[i]}${i < wordArr.length ? wordArr[i] : ''}',
      ).join('');
      lxlrcLines.add('$timeStr$newWords');
    }

    return {
      'lyric': lrcLines.join('\n'),
      'lxlyric': lxlrcLines.join('\n'),
      'tlyric': '',
      'rlyric': '',
    };
  }

  /// 毫秒格式化为 [mm:ss.ms]
  static String _msFormat(int timeMs) {
    if (timeMs <= 0) return '';
    final ms = timeMs % 1000;
    final totalSec = timeMs ~/ 1000;
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '[$m:$s.$ms]';
  }
}
