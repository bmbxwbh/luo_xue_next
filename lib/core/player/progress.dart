import 'dart:async';
import 'package:just_audio/just_audio.dart';
import '../../store/player_store.dart';
import '../../utils/format_util.dart';

/// 播放进度管理 — 对齐 LX Music core/player/progress.ts
class ProgressManager {
  final PlayerStore _playerStore;
  final AudioPlayer _audioPlayer;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  ProgressManager(this._playerStore, this._audioPlayer);

  /// 开始监听进度
  void startListening() {
    stopListening();

    // 监听播放位置
    _positionSub = _audioPlayer.positionStream.listen((position) {
      _playerStore.setNowPlayTime(position.inMilliseconds / 1000.0);
    });

    // 监听总时长
    _durationSub = _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _playerStore.setMaxPlayTime(duration.inMilliseconds / 1000.0);
      }
    });
  }

  /// 停止监听
  void stopListening() {
    _positionSub?.cancel();
    _positionSub = null;
    _durationSub?.cancel();
    _durationSub = null;
  }

  /// 重置进度
  void reset() {
    _playerStore.setProgressDirectly(0, 0);
  }

  /// 设置进度
  void setProgress(double currentTime, double totalTime) {
    _playerStore.setProgressDirectly(currentTime, totalTime);
  }

  /// 跳转到指定时间
  Future<void> seekTo(double seconds) async {
    await _audioPlayer.seek(Duration(milliseconds: (seconds * 1000).toInt()));
  }

  /// 获取当前位置（秒）
  double get currentPosition => _playerStore.progress.nowPlayTime;

  /// 获取总时长（秒）
  double get totalDuration => _playerStore.progress.maxPlayTime;

  void dispose() {
    stopListening();
  }
}
