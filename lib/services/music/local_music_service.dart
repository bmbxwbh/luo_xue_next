import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/song_model.dart';
import '../../models/enums.dart';
import '../../utils/app_logger.dart';

/// 本地音乐扫描服务
class LocalMusicService extends ChangeNotifier {
  final List<SongModel> _songs = [];
  bool _scanning = false;

  List<SongModel> get songs => List.unmodifiable(_songs);
  bool get scanning => _scanning;
  int get count => _songs.length;

  static const _audioExtensions = {
    '.mp3', '.flac', '.ogg', '.wav', '.m4a',
    '.aac', '.wma', '.opus', '.ape', '.aiff',
  };

  /// 扫描本地音乐目录
  Future<int> scanLocalMusic() async {
    if (_scanning) return 0;
    _scanning = true;
    notifyListeners();

    int found = 0;
    try {
      // 请求权限
      if (Platform.isAndroid) {
        final status = await Permission.audio.request();
        if (!status.isGranted) {
          final storage = await Permission.storage.request();
          if (!storage.isGranted) {
            _scanning = false;
            notifyListeners();
            return 0;
          }
        }
      }

      // 扫描常见音乐目录
      final dirs = <Directory>[];

      // 外部存储 / Music
      if (Platform.isAndroid) {
        try {
          final ext = await getExternalStorageDirectory();
          if (ext != null) {
            final base = ext.path.split('/Android')[0];
            final musicDir = Directory('$base/Music');
            if (await musicDir.exists()) dirs.add(musicDir);
            final dlDir = Directory('$base/Download');
            if (await dlDir.exists()) dirs.add(dlDir);
          }
        } catch (_) {}
      }

      // 应用文档目录
      final docDir = await getApplicationDocumentsDirectory();
      if (await docDir.exists()) dirs.add(docDir);

      // 去重扫描
      final seen = <String>{};
      for (final dir in dirs) {
        await _scanDirectory(dir, seen);
      }

      found = _songs.length;
      logger.info('LocalMusicService', '扫描完成，共 $found 首');
    } catch (e) {
      logger.error('LocalMusicService', '扫描出错: $e');
    }

    _scanning = false;
    notifyListeners();
    return found;
  }

  /// 递归扫描目录
  Future<void> _scanDirectory(Directory dir, Set<String> seen, {int depth = 0}) async {
    if (depth > 3) return;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          final ext = _getExtension(entity.path);
          if (_audioExtensions.contains(ext) && !seen.contains(entity.path)) {
            seen.add(entity.path);
            final song = _fileToSong(entity);
            if (song != null) _songs.add(song);
          }
        } else if (entity is Directory && depth < 3) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (!name.startsWith('.')) {
            await _scanDirectory(entity, seen, depth: depth + 1);
          }
        }
      }
    } catch (_) {}
  }

  /// 从文件创建 SongModel
  SongModel? _fileToSong(File file) {
    try {
      final path = file.path;
      final fileName = path.split(Platform.pathSeparator).last;
      final nameWithoutExt = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;

      String singer = '未知歌手';
      String name = nameWithoutExt;
      if (nameWithoutExt.contains(' - ')) {
        final parts = nameWithoutExt.split(' - ');
        if (parts.length >= 2) {
          singer = parts[0].trim();
          name = parts.sublist(1).join(' - ').trim();
        }
      }

      final id = 'local_${path.hashCode}';

      return SongModel(
        id: id,
        name: name,
        singer: singer,
        source: MusicSource.local,
        interval: '',
        intervalSec: 0,
        localPath: path,
        meta: MusicInfoMeta(
          songId: id,
          albumName: '本地音乐',
          picUrl: '',
          qualitys: const [MusicType(type: 'local')],
          qualitysMap: const {'local': MusicType(type: 'local')},
        ),
      );
    } catch (_) {
      return null;
    }
  }

  String _getExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) return '';
    return path.substring(dotIndex).toLowerCase();
  }

  /// 添加单个文件
  void addSong(SongModel song) {
    if (!_songs.any((s) => s.id == song.id)) {
      _songs.add(song);
      notifyListeners();
    }
  }

  /// 从文件列表添加
  void addFiles(List<File> files) {
    for (final file in files) {
      final song = _fileToSong(file);
      if (song != null && !_songs.any((s) => s.id == song.id)) {
        _songs.add(song);
      }
    }
    notifyListeners();
  }

  /// 移除歌曲
  void removeSong(String id) {
    _songs.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  /// 清空
  void clear() {
    _songs.clear();
    notifyListeners();
  }
}
