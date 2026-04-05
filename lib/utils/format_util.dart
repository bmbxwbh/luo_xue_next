
import 'dart:math';

/// 格式化工具 — 对齐 LX Music utils/common.ts

/// 格式化工具类 — 提供静态方法兼容
class FormatUtil {
  /// 解码歌曲名/专辑名
  static String decodeName(String? name) => _topDecodeName(name);

  /// 格式化歌手名
  static String formatSingerName(dynamic singers, {String join = '、'}) =>
      _topFormatSingerName(singers, join: join);

  /// 格式化数字
  static String formatNumber(int num) => _topFormatNumber(num);
}

/// 顶层函数（供其他文件导入调用）
String decodeName(String? name) => _topDecodeName(name);
String formatNumber(int num) => _topFormatNumber(num);
String formatSingerName(dynamic singers, {String nameKey = 'name', String join = '、'}) =>
    _topFormatSingerName(singers, nameKey: nameKey, join: join);

/// 解码HTML实体和Unicode转义
String _topDecodeName(String? name) {
  if (name == null || name.isEmpty) return '';
  String result = name;
  result = result.replaceAll('&amp;', '&');
  result = result.replaceAll('&lt;', '<');
  result = result.replaceAll('&gt;', '>');
  result = result.replaceAll('&quot;', '"');
  result = result.replaceAll('&#39;', "'");
  result = result.replaceAll('&apos;', "'");
  result = result.replaceAllMapped(
    RegExp(r'\\u([0-9a-fA-F]{4})'),
    (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
  );
  return result;
}

/// 格式化数字 (数字 → "1.2万")
String _topFormatNumber(int num) {
  if (num > 100000000) return '${(num / 100000000).toStringAsFixed(1)}亿';
  if (num > 10000) return '${(num / 10000).toStringAsFixed(1)}万';
  return num.toString();
}

/// 格式化文件大小 (字节 → "3.56 MB")
String sizeFormate(int? size) {
  if (size == null || size <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  final number = (log(size) / log(1024)).floor();
  final idx = number.clamp(0, units.length - 1);
  return '${(size / pow(1024, idx)).toStringAsFixed(2)} ${units[idx]}';
}

/// 格式化播放时长 (秒 → "mm:ss" 或 "--/--")
String formatPlayTime(dynamic time) {
  if (time == null) return '--/--';
  final t = time is int ? time.toDouble() : (time is double ? time : double.tryParse(time.toString()) ?? 0);
  final m = t ~/ 60;
  final s = (t % 60).toInt();
  if (m == 0 && s == 0) return '--/--';
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// 格式化播放次数 (数字 → "1.2万" / "3.4亿")
String formatPlayCount(dynamic num) {
  if (num == null) return '0';
  final n = num is int ? num : int.tryParse(num.toString()) ?? 0;
  if (n > 100000000) return '${(n ~/ 10000000) / 10}亿';
  if (n > 10000) return '${(n ~/ 1000) / 10}万';
  return n.toString();
}

/// 格式化歌手名 — 对齐 LX Music formatSingerName
String _topFormatSingerName(dynamic singers, {String nameKey = 'name', String join = '、'}) {
  if (singers is List) {
    final names = <String>[];
    for (final item in singers) {
      if (item is Map) {
        final name = item[nameKey]?.toString();
        if (name != null && name.isNotEmpty) names.add(name);
      } else if (item is String) {
        names.add(item);
      }
    }
    return names.join(join);
  }
  return singers?.toString() ?? '';
}
