import 'package:flutter/foundation.dart';


import '../models/play_music_info.dart';
import '../utils/format_util.dart';

/// 播放进度信息 — 对齐 LX Music Player.progress
class PlayProgress {
  final double nowPlayTime;
  final double maxPlayTime;
  final double progress;
  final String nowPlayTimeStr;
  final String maxPlayTimeStr;

  const PlayProgress({
    this.nowPlayTime = 0,
    this.maxPlayTime = 0,
    this.progress = 0,
    this.nowPlayTimeStr = '00:00',
    this.maxPlayTimeStr = '00:00',
  });

  PlayProgress copyWith({
    double? nowPlayTime,
    double? maxPlayTime,
    double? progress,
    String? nowPlayTimeStr,
    String? maxPlayTimeStr,
  }) {
    return PlayProgress(
      nowPlayTime: nowPlayTime ?? this.nowPlayTime,
      maxPlayTime: maxPlayTime ?? this.maxPlayTime,
      progress: progress ?? this.progress,
      nowPlayTimeStr: nowPlayTimeStr ?? this.nowPlayTimeStr,
      maxPlayTimeStr: maxPlayTimeStr ?? this.maxPlayTimeStr,
    );
  }
}

/// 播放信息 — 对齐 LX Music Player.PlayInfo
class PlayInfo {
  final int playIndex;
  final String? playerListId;
  final int playerPlayIndex;

  const PlayInfo({
    this.playIndex = -1,
    this.playerListId,
    this.playerPlayIndex = -1,
  });

  PlayInfo copyWith({
    int? playIndex,
    String? playerListId,
    int? playerPlayIndex,
  }) {
    return PlayInfo(
      playIndex: playIndex ?? this.playIndex,
      playerListId: playerListId ?? this.playerListId,
      playerPlayIndex: playerPlayIndex ?? this.playerPlayIndex,
    );
  }
}

/// 音乐详细信息 — 对齐 LX Music Player.MusicInfo
class MusicInfo {
  final String? id;
  final String? pic;
  final String? lrc;
  final String? tlrc;
  final String? rlyrc;
  final String? lxlrc;
  final String? rawlrc;
  final String name;
  final String singer;
  final String album;

  const MusicInfo({
    this.id,
    this.pic,
    this.lrc,
    this.tlrc,
    this.rlyrc,
    this.lxlrc,
    this.rawlrc,
    this.name = '',
    this.singer = '',
    this.album = '',
  });

  MusicInfo copyWith({
    String? id,
    String? pic,
    String? lrc,
    String? tlrc,
    String? rlyrc,
    String? lxlrc,
    String? rawlrc,
    String? name,
    String? singer,
    String? album,
  }) {
    return MusicInfo(
      id: id ?? this.id,
      pic: pic ?? this.pic,
      lrc: lrc ?? this.lrc,
      tlrc: tlrc ?? this.tlrc,
      rlyrc: rlyrc ?? this.rlyrc,
      lxlrc: lxlrc ?? this.lxlrc,
      rawlrc: rawlrc ?? this.rawlrc,
      name: name ?? this.name,
      singer: singer ?? this.singer,
      album: album ?? this.album,
    );
  }
}

/// 播放状态管理 — 对齐 LX Music store/player/state.ts
class PlayerStore extends ChangeNotifier {
  /// 是否正在播放
  bool _isPlay = false;
  bool get isPlay => _isPlay;

  /// 当前播放歌曲信息
  PlayMusicInfo? _playMusicInfo;
  PlayMusicInfo? get playMusicInfo => _playMusicInfo;

  /// 播放索引信息
  PlayInfo _playInfo = const PlayInfo(playIndex: -1, playerListId: null);
  PlayInfo get playInfo => _playInfo;

  /// 音乐详细信息（封面、歌词等）
  MusicInfo _musicInfo = const MusicInfo();
  MusicInfo get musicInfo => _musicInfo;

  /// 音量 0.0-1.0
  double _volume = 1.0;
  double get volume => _volume;

  /// 播放速率
  double _playRate = 1.0;
  double get playRate => _playRate;

  /// 状态文本
  String _statusText = '';
  String get statusText => _statusText;

  /// 封面加载失败的URL（避免重复加载）
  String _loadErrorPicUrl = '';
  String get loadErrorPicUrl => _loadErrorPicUrl;

  /// 已播放列表（用于"上一首"回退）
  final List<PlayMusicInfo> _playedList = [];
  List<PlayMusicInfo> get playedList => List.unmodifiable(_playedList);

  /// 稍后播放列表
  final List<PlayMusicInfo> _tempPlayList = [];
  List<PlayMusicInfo> get tempPlayList => List.unmodifiable(_tempPlayList);

  /// 播放进度
  PlayProgress _progress = const PlayProgress();
  PlayProgress get progress => _progress;

  /// 上一句歌词
  String? _lastLyric;
  String? get lastLyric => _lastLyric;

  // ============ Mutations ============

  void setIsPlay(bool value) {
    _isPlay = value;
    notifyListeners();
  }

  void setPlayMusicInfo(PlayMusicInfo? info) {
    _playMusicInfo = info;
    notifyListeners();
  }

  void setPlayInfo(PlayInfo info) {
    _playInfo = info;
    notifyListeners();
  }

  void setMusicInfo(MusicInfo info) {
    _musicInfo = info;
    notifyListeners();
  }

  void patchMusicInfo({
    String? id,
    String? pic,
    String? lrc,
    String? tlrc,
    String? rlyrc,
    String? lxlrc,
    String? rawlrc,
    String? name,
    String? singer,
    String? album,
  }) {
    _musicInfo = _musicInfo.copyWith(
      id: id,
      pic: pic,
      lrc: lrc,
      tlrc: tlrc,
      rlyrc: rlyrc,
      lxlrc: lxlrc,
      rawlrc: rawlrc,
      name: name,
      singer: singer,
      album: album,
    );
    notifyListeners();
  }

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setPlayRate(double value) {
    _playRate = value;
    notifyListeners();
  }

  void setStatusText(String text) {
    _statusText = text;
    notifyListeners();
  }

  void setLoadErrorPicUrl(String url) {
    _loadErrorPicUrl = url;
    notifyListeners();
  }

  void setProgress(PlayProgress progress) {
    _progress = progress;
    notifyListeners();
  }

  void setNowPlayTime(double time) {
    final maxTime = _progress.maxPlayTime;
    final p = maxTime > 0 ? time / maxTime : 0.0;
    _progress = _progress.copyWith(
      nowPlayTime: time,
      progress: p,
      nowPlayTimeStr: formatPlayTime(time.toInt()),
    );
    notifyListeners();
  }

  void setMaxPlayTime(double time) {
    final p = time > 0 ? _progress.nowPlayTime / time : 0.0;
    _progress = _progress.copyWith(
      maxPlayTime: time,
      progress: p,
      maxPlayTimeStr: formatPlayTime(time.toInt()),
    );
    notifyListeners();
  }

  void setProgressDirectly(double currentTime, double totalTime) {
    final p = totalTime > 0 ? currentTime / totalTime : 0.0;
    _progress = PlayProgress(
      nowPlayTime: currentTime,
      maxPlayTime: totalTime,
      progress: p,
      nowPlayTimeStr: formatPlayTime(currentTime.toInt()),
      maxPlayTimeStr: formatPlayTime(totalTime.toInt()),
    );
    notifyListeners();
  }

  void setLastLyric(String? lyric) {
    _lastLyric = lyric;
    notifyListeners();
  }

  void setPlayListId(String? listId) {
    _playInfo = _playInfo.copyWith(playerListId: listId);
    notifyListeners();
  }

  void updatePlayIndex(int playIndex, int playerPlayIndex) {
    _playInfo = _playInfo.copyWith(
      playIndex: playIndex,
      playerPlayIndex: playerPlayIndex,
    );
    notifyListeners();
  }

  // ============ 已播放列表 ============

  void addPlayedList(PlayMusicInfo info) {
    _playedList.add(info);
    notifyListeners();
  }

  void removePlayedList(int index) {
    if (index >= 0 && index < _playedList.length) {
      _playedList.removeAt(index);
      notifyListeners();
    }
  }

  void clearPlayedList() {
    _playedList.clear();
    notifyListeners();
  }

  // ============ 稍后播放列表 ============

  void addTempPlayList(PlayMusicInfo info) {
    _tempPlayList.add(info);
    notifyListeners();
  }

  void removeTempPlayList(int index) {
    if (index >= 0 && index < _tempPlayList.length) {
      _tempPlayList.removeAt(index);
      notifyListeners();
    }
  }

  void clearTempPlayList() {
    _tempPlayList.clear();
    notifyListeners();
  }
}
