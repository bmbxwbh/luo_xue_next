import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../models/enums.dart';
import '../../models/play_music_info.dart';
import '../../models/song_model.dart';
import '../../store/dislike_list_store.dart';
import '../../utils/global.dart';

/// 播放器状态管理
class PlayerService extends ChangeNotifier {
  PlayMusicInfo? _playInfo;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayMode _playMode = PlayMode.listLoop;
  double _volume = 1.0;
  double _speed = 1.0;
  String _currentListId = 'default';
  String _statusText = ''; // 播放状态提示

  // ===== 定时停止播放 =====
  int _timeoutMinutes = 0; // 0 表示不启用
  int _timeoutRemaining = 0; // 剩余秒数
  Timer? _timeoutTimer;
  bool _stopAfterCurrentSong = false; // 播完当前歌曲再停

  // ===== 后台播放计时器 =====
  Timer? _delayNextTimer;
  Timer? _loadTimeoutTimer;

  // ===== 不喜欢列表 =====
  DislikeListStore? _dislikeListStore;

  /// 设置不喜欢列表存储
  void setDislikeListStore(DislikeListStore store) {
    _dislikeListStore = store;
  }

  /// 检查当前播放歌曲是否在不喜欢列表中
  bool get isCurrentSongDisliked {
    if (_playInfo == null || _dislikeListStore == null) return false;
    final song = _playInfo!.musicInfo;
    return _dislikeListStore!.isDisliked(song.name, song.singer);
  }

  PlayMusicInfo? get playInfo => _playInfo;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  PlayMode get playMode => _playMode;
  double get volume => _volume;
  double get speed => _speed;
  String get currentListId => _currentListId;
  String get statusText => _statusText;

  void setStatusText(String text) {
    _statusText = text;
    notifyListeners();
  }
  bool get hasSong => _playInfo != null;

  // ===== 定时停止 getter =====
  int get timeoutMinutes => _timeoutMinutes;
  int get timeoutRemaining => _timeoutRemaining;
  bool get stopAfterCurrentSong => _stopAfterCurrentSong;

  /// 格式化定时剩余时间 "MM:SS"
  String get timeoutStr {
    final m = (_timeoutRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (_timeoutRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// 切换"播完当前歌曲再停"
  void toggleStopAfterCurrentSong() {
    _stopAfterCurrentSong = !_stopAfterCurrentSong;
    notifyListeners();
  }

  void setStopAfterCurrentSong(bool value) {
    _stopAfterCurrentSong = value;
    notifyListeners();
  }

  double get progress {
    if (_duration.inMilliseconds == 0) return 0;
    return _position.inMilliseconds / _duration.inMilliseconds;
  }

  String get positionStr => _formatTime(_position);
  String get durationStr => _formatTime(_duration);

  String _formatTime(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }

  void setPlayInfo(PlayMusicInfo info) {
    _playInfo = info;
    notifyListeners();
  }

  void setPlaying(bool playing) {
    _isPlaying = playing;
    notifyListeners();
  }

  void togglePlay() {
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  void setPosition(Duration pos) {
    _position = pos;
    notifyListeners();
  }

  void setDuration(Duration dur) {
    _duration = dur;
    notifyListeners();
  }

  void setPlayMode(PlayMode mode) {
    _playMode = mode;
    notifyListeners();
  }

  void togglePlayMode() {
    const modes = PlayMode.values;
    final idx = modes.indexOf(_playMode);
    _playMode = modes[(idx + 1) % modes.length];
    notifyListeners();
  }

  void setVolume(double vol) {
    _volume = vol.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setSpeed(double spd) {
    _speed = spd.clamp(0.5, 3.0);
    notifyListeners();
  }

  void setCurrentListId(String id) {
    _currentListId = id;
    notifyListeners();
  }

  /// 播放指定歌曲
  /// 如果歌曲在不喜欢列表中，返回 false 不播放
  bool playSong(SongModel song, {String listId = 'default'}) {
    if (_dislikeListStore != null && _dislikeListStore!.isDisliked(song.name, song.singer)) {
      return false; // 在不喜欢列表中，不播放
    }
    _playInfo = PlayMusicInfo(
      musicInfo: song,
      listId: listId,
    );
    _isPlaying = true;
    _statusText = '正在加载...';
    notifyListeners();

    // 使用全局播放器播放
    _playWithGlobalPlayer(song);

    return true;
  }

  /// 使用全局播放器播放歌曲
  Future<void> _playWithGlobalPlayer(SongModel song) async {
    try {
      await globalPlayer.playMusic(song);
      _statusText = '';
      notifyListeners();
    } catch (e) {
      _statusText = '播放失败: $e';
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// 上一首 / 下一首 (通知UI层处理)
  String? _playAction;

  String? get playAction => _playAction;

  void playPrev() {
    _playAction = 'prev';
    notifyListeners();
    _playAction = null;
  }

  void playNext() {
    // 如果启用了"播完当前歌曲再停"，则暂停播放并停止定时器
    if (_stopAfterCurrentSong && _timeoutMinutes > 0) {
      _stopAfterCurrentSong = false;
      _timeoutTimer?.cancel();
      _timeoutTimer = null;
      _timeoutMinutes = 0;
      _timeoutRemaining = 0;
      if (_isPlaying) {
        _isPlaying = false;
        globalPlayer.pause();
      }
      notifyListeners();
      return;
    }
    _playAction = 'next';
    notifyListeners();
    _playAction = null;
  }

  /// 从播放列表中获取下一首非不喜欢歌曲的索引
  /// 返回 -1 表示没有可播放的歌曲
  int getNextPlayableIndex(List<SongModel> playlist, int currentIndex, PlayMode mode) {
    if (playlist.isEmpty) return -1;
    if (_dislikeListStore == null) {
      return _computeNextIndex(playlist, currentIndex, mode);
    }

    // 最多遍历整个列表，防止死循环
    final maxAttempts = playlist.length;
    int nextIndex = _computeNextIndex(playlist, currentIndex, mode);
    for (int i = 0; i < maxAttempts; i++) {
      if (nextIndex < 0 || nextIndex >= playlist.length) return -1;
      final song = playlist[nextIndex];
      if (!_dislikeListStore!.isDisliked(song.name, song.singer)) {
        return nextIndex;
      }
      nextIndex = _computeNextIndex(playlist, nextIndex, mode);
    }
    return -1; // 所有歌曲都在不喜欢列表中
  }

  static int _computeNextIndex(List<SongModel> playlist, int currentIndex, PlayMode mode) {
    if (playlist.isEmpty) return -1;
    final safeIndex = currentIndex.clamp(0, playlist.length - 1);
    switch (mode) {
      case PlayMode.listLoop:
        return safeIndex == playlist.length - 1 ? 0 : safeIndex + 1;
      case PlayMode.random:
        final random = Random();
        return random.nextInt(playlist.length);
      case PlayMode.list:
        return safeIndex == playlist.length - 1 ? -1 : safeIndex + 1;
      case PlayMode.singleLoop:
        return safeIndex;
    }
  }

  void seekTo(double ratio) {
    final ms = (_duration.inMilliseconds * ratio).round();
    _position = Duration(milliseconds: ms);
    notifyListeners();
  }

  // ===== 定时停止播放 =====

  /// 设置定时停止，0 取消
  void setTimeoutExit(int minutes) {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _timeoutMinutes = minutes;

    if (minutes <= 0) {
      _timeoutRemaining = 0;
      notifyListeners();
      return;
    }

    _timeoutRemaining = minutes * 60;
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _timeoutRemaining--;
      if (_timeoutRemaining <= 0) {
        timer.cancel();
        _timeoutTimer = null;
        _timeoutMinutes = 0;
        _timeoutRemaining = 0;
        // 时间到，暂停播放
        if (_isPlaying) {
          _isPlaying = false;
          globalPlayer.pause();
        }
      }
      notifyListeners();
    });
    notifyListeners();
  }

  // ===== 后台播放计时器 =====

  /// 创建延迟切换下一首的计时器
  void _createDelayNextTimeout(int delayMs) {
    _delayNextTimer?.cancel();
    _delayNextTimer = Timer(Duration(milliseconds: delayMs), () {
      _delayNextTimer = null;
      playNext();
    });
  }

  /// 播放失败时随机延迟(2-6秒)重试
  void retryWithDelay() {
    final random = Random();
    final delayMs = 2000 + random.nextInt(4000); // 2000 ~ 6000 ms
    _createDelayNextTimeout(delayMs);
  }

  /// 播放加载超时(100秒)后自动切换下一首
  void startLoadTimeout() {
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = Timer(const Duration(seconds: 100), () {
      _loadTimeoutTimer = null;
      playNext();
    });
  }

  /// 取消加载超时计时器(播放成功时调用)
  void cancelLoadTimeout() {
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = null;
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _delayNextTimer?.cancel();
    _loadTimeoutTimer?.cancel();
    super.dispose();
  }
}
