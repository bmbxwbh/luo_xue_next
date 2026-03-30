/// 日志上传服务 — 将 app 日志上传到服务器供远程分析
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogUploadService {
  static const _uploadUrl = 'http://47.236.26.115:9876/upload';
  static const _maxBufferSize = 2000; // 最大缓存条数（和 AppLogger 一致）

  final List<Map<String, dynamic>> _buffer = [];
  String _deviceId = 'unknown';
  bool _enabled = false;

  static final LogUploadService _instance = LogUploadService._();
  factory LogUploadService() => _instance;
  LogUploadService._();

  bool get enabled => _enabled;

  /// 初始化
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool('log_upload_enabled') ?? false;

      // 生成设备 ID
      _deviceId = prefs.getString('log_device_id') ?? '';
      if (_deviceId.isEmpty) {
        _deviceId = 'flutter_${Platform.operatingSystem}_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
        await prefs.setString('log_device_id', _deviceId);
      }

      if (_enabled) {
        debugPrint('[LogUpload] 已启用，等待手动上传');
      }
      debugPrint('[LogUpload] 初始化完成 enabled=$_enabled deviceId=$_deviceId');
    } catch (e) {
      debugPrint('[LogUpload] 初始化失败: $e');
    }
  }

  /// 开关
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('log_upload_enabled', enabled);
    if (!enabled) _buffer.clear();
    debugPrint('[LogUpload] ${enabled ? "已启用" : "已禁用"}');
  }

  /// 添加日志条目
  void addLog(String level, String tag, String msg) {
    if (!_enabled) return;
    _buffer.add({
      'ts': DateTime.now().toIso8601String(),
      'level': level,
      'tag': tag,
      'msg': msg.length > 2000 ? msg.substring(0, 2000) : msg,
    });
    // 防止内存溢出
    if (_buffer.length > _maxBufferSize) {
      _buffer.removeRange(0, _buffer.length - _maxBufferSize);
    }
  }

  /// 获取缓存数量
  int get bufferedCount => _buffer.length;

  /// 手动上传所有缓存日志
  Future<bool> uploadNow() async {
    if (_buffer.isEmpty) return true;
    final batch = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.postUrl(Uri.parse(_uploadUrl));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'deviceId': _deviceId,
        'logs': batch,
      }));
      final response = await request.close().timeout(const Duration(seconds: 10));
      final body = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode == 200) {
        debugPrint('[LogUpload] 上传成功 ${batch.length} 条');
        return true;
      } else {
        debugPrint('[LogUpload] 上传失败: ${response.statusCode} $body');
        _buffer.insertAll(0, batch);
        return false;
      }
    } catch (e) {
      debugPrint('[LogUpload] 上传异常: $e');
      _buffer.insertAll(0, batch);
      return false;
    }
  }

  void dispose() {}
}
