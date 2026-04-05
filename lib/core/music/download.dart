import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import '../../models/enums.dart';
import '../../models/song_model.dart';
import 'online.dart';

/// 下载任务状态
enum DownloadStatus { pending, downloading, completed, failed, paused }

/// 下载任务信息
class DownloadTask {
  final String id;
  final SongModel musicInfo;
  final Quality quality;
  DownloadStatus status;
  double progress; // 0.0 - 1.0
  int downloadedBytes;
  int totalBytes;
  String? filePath;
  String? errorMessage;

  DownloadTask({
    required this.id,
    required this.musicInfo,
    required this.quality,
    this.status = DownloadStatus.pending,
    this.progress = 0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.filePath,
    this.errorMessage,
  });
}

/// 下载管理 — 对齐 LX Music core/music/download.dart
class DownloadManager {
  final OnlineMusicService _onlineMusicService;
  final Map<String, DownloadTask> _tasks = {};
  final Map<String, HttpClient> _activeClients = {};

  /// 下载完成回调
  final _onTaskUpdated = StreamController<DownloadTask>.broadcast();
  Stream<DownloadTask> get onTaskUpdated => _onTaskUpdated.stream;

  DownloadManager(this._onlineMusicService);

  /// 获取所有任务
  List<DownloadTask> get tasks => _tasks.values.toList();

  /// 获取指定任务
  DownloadTask? getTask(String id) => _tasks[id];

  /// 开始下载
  Future<void> download({
    required SongModel musicInfo,
    required Quality quality,
    String? savePath,
  }) async {
    final taskId = '${musicInfo.id}_${quality.value}';

    // 已存在任务则跳过
    if (_tasks.containsKey(taskId) &&
        _tasks[taskId]!.status == DownloadStatus.downloading) {
      return;
    }

    final task = DownloadTask(
      id: taskId,
      musicInfo: musicInfo,
      quality: quality,
    );
    _tasks[taskId] = task;

    try {
      // 获取播放链接
      task.status = DownloadStatus.downloading;
      _notifyTask(task);

      final url = await _onlineMusicService.getMusicUrl(
        musicInfo: musicInfo,
        quality: quality,
      );

      if (url == null || url.isEmpty) {
        task.status = DownloadStatus.failed;
        task.errorMessage = '获取下载链接失败';
        _notifyTask(task);
        return;
      }

      // 确定保存路径
      String filePath;
      if (savePath != null) {
        filePath = savePath;
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final ext = quality.value.contains('flac') ? 'flac' : 'mp3';
        final fileName = '${musicInfo.name} - ${musicInfo.singer}.$ext';
        filePath = '${dir.path}/downloads/$fileName';
      }

      // 确保目录存在
      final file = File(filePath);
      await file.parent.create(recursive: true);

      // 下载文件
      final client = HttpClient();
      _activeClients[taskId] = client;

      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      task.totalBytes = response.contentLength;
      final sink = file.openWrite();
      int received = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        task.downloadedBytes = received;
        task.progress = task.totalBytes > 0
            ? received / task.totalBytes
            : 0;
        _notifyTask(task);
      }

      await sink.close();
      _activeClients.remove(taskId);

      task.status = DownloadStatus.completed;
      task.filePath = filePath;
      task.progress = 1.0;
      _notifyTask(task);
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.errorMessage = e.toString();
      _activeClients.remove(taskId);
      _notifyTask(task);
    }
  }

  /// 暂停下载
  void pause(String taskId) {
    final client = _activeClients[taskId];
    if (client != null) {
      client.close();
      _activeClients.remove(taskId);
    }
    final task = _tasks[taskId];
    if (task != null) {
      task.status = DownloadStatus.paused;
      _notifyTask(task);
    }
  }

  /// 取消下载
  void cancel(String taskId) {
    pause(taskId);
    _tasks.remove(taskId);
  }

  /// 重试下载
  Future<void> retry(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;
    _tasks.remove(taskId);
    await download(
      musicInfo: task.musicInfo,
      quality: task.quality,
    );
  }

  /// 清除已完成的任务
  void clearCompleted() {
    _tasks.removeWhere((_, task) => task.status == DownloadStatus.completed);
  }

  void _notifyTask(DownloadTask task) {
    _onTaskUpdated.add(task);
  }

  /// 释放资源
  void dispose() {
    for (final client in _activeClients.values) {
      client.close();
    }
    _activeClients.clear();
    _onTaskUpdated.close();
  }
}
