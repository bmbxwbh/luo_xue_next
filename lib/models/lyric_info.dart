/// 歌词行
class LyricLine {
  /// 时间（秒）
  final double time;

  /// 原文歌词
  final String text;

  /// 翻译歌词（可选）
  final String? translation;

  const LyricLine({
    required this.time,
    required this.text,
    this.translation,
  });

  /// 格式化时间 "MM:SS.xx"
  String get timeStr {
    final minutes = (time / 60).floor();
    final seconds = time % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toStringAsFixed(2).padLeft(5, '0')}';
  }

  /// 合并翻译
  String get displayText {
    if (translation != null && translation!.isNotEmpty) {
      return '$text\n$translation';
    }
    return text;
  }
}

/// 歌词信息 — 对齐 LX Music LyricInfo
class LyricInfo {
  /// 原文歌词
  final String lyric;

  /// 翻译歌词
  final String? tlyric;

  /// 罗马音歌词
  final String? rlyric;

  /// 逐字歌词
  final String? lxlrc;

  const LyricInfo({
    required this.lyric,
    this.tlyric,
    this.rlyric,
    this.lxlrc,
  });

  /// 解析 LRC 歌词为 LyricLine 列表
  /// 自动合并翻译歌词
  List<LyricLine> parseLrc() {
    final lines = _parseLrcText(lyric);
    final translations = tlyric != null ? _parseLrcText(tlyric!) : <double, String>{};

    final result = <LyricLine>[];
    for (final entry in lines.entries) {
      result.add(LyricLine(
        time: entry.key,
        text: entry.value,
        translation: translations[entry.key],
      ));
    }
    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }

  /// 解析逐字歌词
  List<LyricLine> parseLxlrc() {
    if (lxlrc == null || lxlrc!.isEmpty) return parseLrc();
    final parsed = _parseLrcText(lxlrc!);
    final result = <LyricLine>[];
    for (final e in parsed.entries) {
      result.add(LyricLine(time: e.key, text: e.value));
    }
    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }

  /// 解析 LRC 文本为 time→text Map
  static Map<double, String> _parseLrcText(String lrcText) {
    final result = <double, String>{};
    final lines = lrcText.split(RegExp(r'\r?\n'));

    // LRC 格式: [mm:ss.xx] 歌词文本
    final timeRegex = RegExp(r'\[(\d{1,2}):(\d{1,2})(?:\.(\d{1,4}))?\]');

    for (final line in lines) {
      final matches = timeRegex.allMatches(line);
      if (matches.isEmpty) continue;

      // 获取歌词文本（去掉所有时间标签后的部分）
      String text = line;
      for (final match in matches) {
        text = text.replaceFirst(match.group(0)!, '');
      }
      text = text.trim();

      for (final match in matches) {
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
        final msStr = match.group(3) ?? '0';
        final ms = double.tryParse('0.$msStr') ?? 0.0;
        final time = minutes * 60.0 + seconds + ms;
        result[time] = text;
      }
    }

    return result;
  }

  /// 是否有内容
  bool get hasLyric => lyric.isNotEmpty;

  /// 是否有翻译
  bool get hasTranslation => tlyric != null && tlyric!.isNotEmpty;

  /// 是否有罗马音
  bool get hasRomaLyric => rlyric != null && rlyric!.isNotEmpty;

  /// 是否有逐字歌词
  bool get hasLxlrc => lxlrc != null && lxlrc!.isNotEmpty;

  /// 是否为空
  bool get isEmpty => lyric.isEmpty;

  Map<String, dynamic> toJson() => {
        'lyric': lyric,
        if (tlyric != null) 'tlyric': tlyric,
        if (rlyric != null) 'rlyric': rlyric,
        if (lxlrc != null) 'lxlrc': lxlrc,
      };

  factory LyricInfo.fromJson(Map<String, dynamic> json) {
    return LyricInfo(
      lyric: json['lyric'] ?? '',
      tlyric: json['tlyric'],
      rlyric: json['rlyric'],
      lxlrc: json['lxlrc'],
    );
  }

  @override
  String toString() =>
      'LyricInfo(hasLyric: $hasLyric, hasTranslation: $hasTranslation, lines: ${parseLrc().length})';
}
