import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 日志级别
enum LogLevel { debug, info, warn, error }

/// 日志条目
class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;
  final String? stackTrace;

  const LogEntry({
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
    this.stackTrace,
  });

  String get levelStr => switch (level) {
        LogLevel.debug => 'DEBUG',
        LogLevel.info => 'INFO',
        LogLevel.warn => 'WARN',
        LogLevel.error => 'ERROR',
      };

  String format() {
    final ts =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
    final sb = StringBuffer('[$ts] [$levelStr] [$tag] $message');
    if (stackTrace != null) sb.write('\n$stackTrace');
    return sb.toString();
  }

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'level': levelStr,
        'tag': tag,
        'message': message,
        if (stackTrace != null) 'stackTrace': stackTrace,
      };
}

/// 应用日志收集器 — 开发者模式
class AppLogger extends ChangeNotifier {
  static final AppLogger _instance = AppLogger._();
  factory AppLogger() => _instance;
  AppLogger._();

  bool _enabled = true; // 默认开启，由用户在设置中关闭
  final Queue<LogEntry> _logs = Queue();
  static const int _maxLogs = 2000;
  String? _lastMessage; // 防重复

  bool get enabled => _enabled;
  List<LogEntry> get logs => _logs.toList();
  int get errorCount =>
      _logs.where((l) => l.level == LogLevel.error).length;

  void setEnabled(bool value) {
    _enabled = value;
    notifyListeners();
  }

  void log(LogLevel level, String tag, String message, {String? stackTrace}) {
    if (!_enabled && level != LogLevel.error) return;

    // 防重复：跳过与上一条完全相同的消息
    final fullMsg = '[$tag] $message';
    if (fullMsg == _lastMessage) return;
    _lastMessage = fullMsg;

    final entry = LogEntry(
      time: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      stackTrace: stackTrace,
    );

    _logs.add(entry);
    while (_logs.length > _maxLogs) {
      _logs.removeFirst();
    }

    // 错误日志即使未开启开发者模式也记录
    if (level == LogLevel.error) {
      _saveErrorToFile(entry);
    }

    notifyListeners();
  }

  void debug(String tag, String msg) => log(LogLevel.debug, tag, msg);
  void info(String tag, String msg) => log(LogLevel.info, tag, msg);
  void warn(String tag, String msg) => log(LogLevel.warn, tag, msg);
  void error(String tag, String msg, {StackTrace? st}) =>
      log(LogLevel.error, tag, msg, stackTrace: st?.toString());

  /// 获取所有日志文本
  String exportText() {
    final sb = StringBuffer();
    sb.writeln('=== 洛雪Next 日志导出 ===');
    sb.writeln('时间: ${DateTime.now()}');
    sb.writeln('日志数量: ${_logs.length}');
    sb.writeln('错误数量: $errorCount');
    sb.writeln('========================\n');
    for (final entry in _logs) {
      sb.writeln(entry.format());
    }
    return sb.toString();
  }

  /// 获取 JSON 格式日志
  String exportJson() {
    return jsonEncode({
      'exportTime': DateTime.now().toIso8601String(),
      'totalLogs': _logs.length,
      'errorCount': errorCount,
      'logs': _logs.map((e) => e.toJson()).toList(),
    });
  }

  /// 清空日志
  void clear() {
    _logs.clear();
    notifyListeners();
  }

  /// 保存错误到文件
  Future<void> _saveErrorToFile(LogEntry entry) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/error_log.txt');
      final sink = file.openWrite(mode: FileMode.append);
      sink.writeln(entry.format());
      await sink.close();
    } catch (_) {}
  }

  /// 获取错误日志文件路径
  Future<String> getErrorLogPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/error_log.txt';
  }

  /// 清除错误日志文件
  Future<void> clearErrorFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/error_log.txt');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

/// 全局 logger 实例
final logger = AppLogger();
