import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../../models/enums.dart';
import '../../models/song_model.dart';
import '../../models/play_music_info.dart';
import '../../store/player_store.dart';
import '../../services/settings/setting_store.dart';
import '../../utils/url_cache.dart';
import '../music/online.dart';
import 'play_info.dart';
import 'progress.dart';

/// 随机数生成
int _getRandom(int min, int max) {
  if (min >= max) return min;
  return min + Random().nextInt(max - min);
}

/// 播放核心 — 对齐 LX Music core/player/player.ts
class Player {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final PlayerStore _playerStore;
  final SettingStore _settingStore;
  late final PlayInfoManager _playInfoManager;
  late final ProgressManager _progressManager;
  late final OnlineMusicService _onlineMusicService;

  bool _isInitialized = false;
  String _gettingUrlId = '';

  /// 上一首预加载信息
  PlayMusicInfo? _randomNextMusicInfo;

  Player({
    required PlayerStore playerStore,
    required SettingStore settingStore,
    required OnlineMusicService onlineMusicService,
  })  : _playerStore = playerStore,
        _settingStore = settingStore,
        _onlineMusicService = onlineMusicService {
    _playInfoManager = PlayInfoManager(_playerStore);
    _progressManager = ProgressManager(_playerStore, _audioPlayer);

    // 监听播放完成事件
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _playerStore.setIsPlay(false);
        playNext(isAutoToggle: true);
      }
    });
  }

  PlayInfoManager get playInfoManager => _playInfoManager;
  ProgressManager get progressManager => _progressManager;
  AudioPlayer get audioPlayer => _audioPlayer;

  /// 初始化音频会话
  Future<void> init() async {
    if (_isInitialized) return;
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _isInitialized = true;
  }

  /// 检查当前歌曲是否已变更
  bool _diffCurrentMusicInfo(SongModel musicInfo) {
    final currentId = _gettingUrlId;
    final newId = '${musicInfo.id}_${musicInfo.meta.songId}';
    return newId != currentId ||
        musicInfo.id != _playerStore.playMusicInfo?.musicInfo.id ||
        _playerStore.isPlay;
  }

  /// 获取音乐播放URL并设置
  Future<void> _setMusicUrl(SongModel musicInfo, {bool isRefresh = false}) async {
    if (!_diffCurrentMusicInfo(musicInfo)) return;
    _gettingUrlId = '${musicInfo.id}_${musicInfo.meta.songId}';

    try {
      final quality = _settingStore.quality;
      String? url;

      // 非刷新时，先查缓存
      if (!isRefresh) {
        _playerStore.setStatusText('正在检查缓存...');
        url = await UrlCache.getUrl(
          musicInfo.source.id,
          musicInfo.songmid,
          quality.value,
        );
      }

      if (url != null && url.isNotEmpty) {
        _playerStore.setStatusText('正在播放...');
        debugPrint('[Player] URL 来自缓存: $url');
        await _setResource(musicInfo, url);
        return;
      }

      _playerStore.setStatusText('正在获取播放链接...');
      url = await _onlineMusicService.getMusicUrl(
        musicInfo: musicInfo,
        quality: quality,
        isRefresh: isRefresh,
      );
      debugPrint('[Player] URL 来自在线: $url');

      if (url == null || url.isEmpty) {
        _playerStore.setStatusText('获取播放链接失败');
        _tryPlayNext();
        return;
      }

      // 缓存 URL
      await UrlCache.setUrl(
        musicInfo.source.id,
        musicInfo.songmid,
        quality.value,
        url,
      );

      await _setResource(musicInfo, url);
    } catch (e) {
      _playerStore.setStatusText('获取播放链接失败: $e');
      _tryPlayNext();
    } finally {
      if (musicInfo.id == _playerStore.playMusicInfo?.musicInfo.id) {
        _gettingUrlId = '';
      }
    }
  }

  /// 设置音频资源并播放
  Future<void> _setResource(SongModel musicInfo, String url) async {
    try {
      debugPrint('[Player] _setResource: 设置音频 URL=$url');
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
      debugPrint('[Player] _setResource: 播放成功');
      _playerStore.setIsPlay(true);
      _playerStore.setStatusText('');

      // 开始监听进度
      _progressManager.startListening();

      // 获取封面
      _fetchPic(musicInfo);
      // 获取歌词
      _fetchLyric(musicInfo);
    } catch (e) {
      _playerStore.setStatusText('播放失败: $e');
      _tryPlayNext();
    }
  }

  /// 获取封面
  void _fetchPic(SongModel musicInfo) async {
    try {
      final url = await _onlineMusicService.getPicPath(musicInfo);
      if (url != null &&
          url.isNotEmpty &&
          musicInfo.id == _playerStore.playMusicInfo?.musicInfo.id &&
          _playerStore.musicInfo.pic != url) {
        _playerStore.patchMusicInfo(pic: url);
      }
    } catch (_) {}
  }

  /// 获取歌词
  void _fetchLyric(SongModel musicInfo) async {
    try {
      final lyricInfo = await _onlineMusicService.getLyricInfo(musicInfo);
      if (musicInfo.id == _playerStore.playMusicInfo?.musicInfo.id) {
        _playerStore.patchMusicInfo(
          lrc: lyricInfo.lyric,
          tlrc: lyricInfo.tlyric,
          lxlyric: lyricInfo.lxlyric,
          rlyrc: lyricInfo.rlyric,
        );
      }
    } catch (e) {
      if (musicInfo.id == _playerStore.playMusicInfo?.musicInfo.id) {
        _playerStore.setStatusText('歌词加载失败');
      }
    }
  }

  /// 处理播放
  Future<void> _handlePlay() async {
    await init();
    _randomNextMusicInfo = null;

    final playMusicInfo = _playerStore.playMusicInfo;
    if (playMusicInfo == null) return;

    final musicInfo = playMusicInfo.musicInfo;

    // 停止当前播放
    await _audioPlayer.stop();
    _playerStore.setIsPlay(false);
    _progressManager.reset();

    // 添加到已播放列表（随机模式）
    if (_settingStore.playMode == PlayMode.random &&
        !playMusicInfo.isTempPlay) {
      _playerStore.addPlayedList(playMusicInfo);
    }

    _setMusicUrl(musicInfo);
  }

  /// 延迟尝试下一首
  void _tryPlayNext() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!_playerStore.isPlay) {
        playNext(isAutoToggle: true);
      }
    });
  }

  // ============ 公开API ============

  /// 播放指定歌曲
  Future<void> playMusic(SongModel song) async {
    debugPrint('[Player] playMusic: ${song.name} (${song.source.id}_${song.songmid})');
    _playerStore.setPlayMusicInfo(PlayMusicInfo(
      musicInfo: song,
      listId: 'default',
    ));
    debugPrint('[Player] playMusicInfo 已设置, playMusicInfo=${_playerStore.playMusicInfo?.musicInfo.name}');

    // 本地音乐直接播放
    if (song.source == MusicSource.local && song.localPath != null) {
      _playerStore.setStatusText('');
      try {
        await _audioPlayer.setUrl(song.localPath!);
        await _audioPlayer.play();
        _playerStore.setIsPlay(true);
        _progressManager.startListening();
      } catch (e) {
        _playerStore.setStatusText('播放失败: $e');
      }
      return;
    }

    await _setMusicUrl(song);
  }

  /// 播放
  void play() {
    final playMusicInfo = _playerStore.playMusicInfo;
    if (playMusicInfo == null) return;

    final musicInfo = playMusicInfo.musicInfo;
    final currentId = '${musicInfo.id}_${musicInfo.meta.songId}';

    if (_audioPlayer.audioSource == null) {
      if (currentId != _gettingUrlId) {
        _setMusicUrl(musicInfo);
      }
      return;
    }
    _audioPlayer.play();
    _playerStore.setIsPlay(true);
  }

  /// 暂停
  Future<void> pause() async {
    await _audioPlayer.pause();
    _playerStore.setIsPlay(false);
  }

  /// 停止
  Future<void> stop() async {
    await _audioPlayer.stop();
    _playerStore.setIsPlay(false);
    _progressManager.reset();
  }

  /// 切换播放/暂停
  void togglePlay() {
    if (_playerStore.isPlay) {
      pause();
    } else {
      play();
    }
  }

  /// 跳转
  Future<void> seekTo(Duration position) async {
    await _progressManager.seekTo(position.inMilliseconds / 1000.0);
  }

  /// 设置播放列表并播放
  Future<void> setPlayList(List<SongModel> songs, {String? listId, int startIndex = 0}) async {
    if (songs.isEmpty) return;
    final prevListId = _playerStore.playInfo.playerListId;

    _playerStore.setPlayListId(listId);
    _playInfoManager.setPlayMusicInfo(listId, songs[startIndex]);

    if (_settingStore.isAutoCleanPlayedList || prevListId != listId) {
      _playerStore.clearPlayedList();
    }
    _playerStore.clearTempPlayList();

    await _handlePlay();
  }

  /// 根据列表ID和歌曲ID播放
  Future<void> playListById(String listId, String musicId, List<SongModel> list) async {
    if (list.isEmpty) return;
    final prevListId = _playerStore.playInfo.playerListId;
    _playerStore.setPlayListId(listId);

    final musicInfo = list.firstWhere(
      (m) => m.id == musicId,
      orElse: () => list.first,
    );
    _playInfoManager.setPlayMusicInfo(listId, musicInfo);

    if (_settingStore.isAutoCleanPlayedList || prevListId != listId) {
      _playerStore.clearPlayedList();
    }
    _playerStore.clearTempPlayList();

    await _handlePlay();
  }

  /// 添加到播放列表
  void addToPlayList(SongModel song) {
    _playerStore.addTempPlayList(PlayMusicInfo(
      musicInfo: song,
      listId: _playerStore.playInfo.playerListId ?? '',
      isTempPlay: true,
    ));
  }

  /// 稍后播放
  void playLater(SongModel song) {
    _playerStore.addTempPlayList(PlayMusicInfo(
      musicInfo: song,
      listId: _playerStore.playInfo.playerListId ?? '',
      isTempPlay: true,
    ));
  }

  /// 获取下一首播放信息
  PlayMusicInfo? _getNextPlayMusicInfo(List<SongModel> Function(String?) getListMusics) {
    // 优先播放稍后播放列表
    if (_playerStore.tempPlayList.isNotEmpty) {
      return _playerStore.tempPlayList.first;
    }

    if (_playerStore.playMusicInfo?.musicInfo == null) return null;

    if (_randomNextMusicInfo != null) return _randomNextMusicInfo;

    final playInfo = _playerStore.playInfo;
    final currentListId = playInfo.playerListId;
    if (currentListId == null) return null;

    final currentList = getListMusics(currentListId);
    final playedList = _playerStore.playedList;

    // 从已播放列表取下一首
    if (playedList.isNotEmpty) {
      final currentId = _playerStore.playMusicInfo!.musicInfo.id;
      int index = playedList.indexWhere((m) => m.musicInfo.id == currentId) + 1;

      for (; index < playedList.length; index++) {
        final pmi = playedList[index];
        if (pmi.listId == currentListId &&
            !currentList.any((m) => m.id == pmi.musicInfo.id)) {
          _playerStore.removePlayedList(index);
          continue;
        }
        break;
      }

      if (index < playedList.length) return playedList[index];
    }

    // 过滤已播放歌曲
    final currentIndex = playInfo.playerPlayIndex;
    if (currentList.isEmpty) return null;
    final safeIndex = currentIndex.clamp(0, currentList.length - 1);

    int nextIndex = safeIndex;
    final mode = _settingStore.playMode;
    switch (mode) {
      case PlayMode.listLoop:
        nextIndex = safeIndex == currentList.length - 1 ? 0 : safeIndex + 1;
        break;
      case PlayMode.random:
        nextIndex = _getRandom(0, currentList.length);
        break;
      case PlayMode.list:
        nextIndex = safeIndex == currentList.length - 1 ? -1 : safeIndex + 1;
        break;
      case PlayMode.singleLoop:
        nextIndex = safeIndex;
        break;
    }

    if (nextIndex < 0) return null;

    final nextInfo = PlayMusicInfo(
      musicInfo: currentList[nextIndex],
      listId: currentListId,
      isTempPlay: false,
    );

    if (mode == PlayMode.random) {
      _randomNextMusicInfo = nextInfo;
    }

    return nextInfo;
  }

  /// 下一首
  Future<void> playNext({bool isAutoToggle = false, List<SongModel> Function(String?)? getListMusics}) async {
    final getter = getListMusics ?? (_) => [];

    // 优先播放稍后播放列表
    if (_playerStore.tempPlayList.isNotEmpty) {
      final info = _playerStore.tempPlayList.first;
      _playerStore.removeTempPlayList(0);
      _playInfoManager.setPlayMusicInfo(info.listId, info.musicInfo, isTempPlay: info.isTempPlay);
      await _handlePlay();
      return;
    }

    final playMusicInfo = _playerStore.playMusicInfo;
    if (playMusicInfo?.musicInfo == null) {
      await stop();
      _playInfoManager.setPlayMusicInfo(null, null);
      return;
    }

    final currentListId = _playerStore.playInfo.playerListId;
    if (currentListId == null) {
      await stop();
      _playInfoManager.setPlayMusicInfo(null, null);
      return;
    }

    final currentList = getter(currentListId);
    if (currentList.isEmpty) {
      await stop();
      return;
    }

    final currentIndex = _playerStore.playInfo.playerPlayIndex.clamp(0, currentList.length - 1);

    // 使用预加载的下一首
    if (_randomNextMusicInfo != null) {
      final info = _randomNextMusicInfo!;
      _randomNextMusicInfo = null;
      _playInfoManager.setPlayMusicInfo(info.listId, info.musicInfo);
      await _handlePlay();
      return;
    }

    int nextIndex = currentIndex;
    var mode = _settingStore.playMode;

    // 非自动切换时，强制列表循环
    if (!isAutoToggle) {
      switch (mode) {
        case PlayMode.list:
        case PlayMode.singleLoop:
          mode = PlayMode.listLoop;
        default:
          break;
      }
    }

    switch (mode) {
      case PlayMode.listLoop:
        nextIndex = currentIndex == currentList.length - 1 ? 0 : currentIndex + 1;
        break;
      case PlayMode.random:
        nextIndex = _getRandom(0, currentList.length);
        break;
      case PlayMode.list:
        nextIndex = currentIndex == currentList.length - 1 ? -1 : currentIndex + 1;
        break;
      case PlayMode.singleLoop:
        nextIndex = currentIndex;
        break;
    }

    if (nextIndex < 0) return;

    _playInfoManager.setPlayMusicInfo(currentListId, currentList[nextIndex]);
    await _handlePlay();
  }

  /// 上一首
  Future<void> playPrevious({bool isAutoToggle = false, List<SongModel> Function(String?)? getListMusics}) async {
    final getter = getListMusics ?? (_) => [];
    final playMusicInfo = _playerStore.playMusicInfo;
    if (playMusicInfo?.musicInfo == null) {
      await stop();
      _playInfoManager.setPlayMusicInfo(null, null);
      return;
    }

    final currentListId = _playerStore.playInfo.playerListId;
    if (currentListId == null) {
      await stop();
      return;
    }

    final currentList = getter(currentListId);
    if (currentList.isEmpty) {
      await stop();
      return;
    }

    final playedList = _playerStore.playedList;
    if (playedList.isNotEmpty) {
      final currentId = playMusicInfo!.musicInfo.id;
      int index = playedList.indexWhere((m) => m.musicInfo.id == currentId) - 1;

      for (; index >= 0; index--) {
        final pmi = playedList[index];
        if (pmi.listId == currentListId &&
            !currentList.any((m) => m.id == pmi.musicInfo.id)) {
          _playerStore.removePlayedList(index);
          continue;
        }
        break;
      }

      if (index >= 0) {
        final info = playedList[index];
        _playInfoManager.setPlayMusicInfo(info.listId, info.musicInfo);
        await _handlePlay();
        return;
      }
    }

    final currentIndex = _playerStore.playInfo.playerPlayIndex.clamp(0, currentList.length - 1);
    int nextIndex = currentIndex;

    var mode = _settingStore.playMode;
    if (!isAutoToggle) {
      switch (mode) {
        case PlayMode.list:
        case PlayMode.singleLoop:
          mode = PlayMode.listLoop;
        default:
          break;
      }
    }

    switch (mode) {
      case PlayMode.random:
        nextIndex = _getRandom(0, currentList.length);
        break;
      case PlayMode.listLoop:
      case PlayMode.list:
        nextIndex = currentIndex == 0 ? currentList.length - 1 : currentIndex - 1;
        break;
      case PlayMode.singleLoop:
        nextIndex = currentIndex;
        break;
    }

    _playInfoManager.setPlayMusicInfo(currentListId, currentList[nextIndex]);
    await _handlePlay();
  }

  /// 切换播放模式
  void togglePlayMode() {
    final modes = PlayMode.values;
    final currentIndex = modes.indexOf(_settingStore.playMode);
    final nextIndex = (currentIndex + 1) % modes.length;
    _settingStore.setPlayMode(modes[nextIndex]);
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    final v = volume.clamp(0.0, 1.0);
    await _audioPlayer.setVolume(v);
    _playerStore.setVolume(v);
    _settingStore.setVolume(v);
  }

  /// 设置播放速率
  Future<void> setPlayRate(double rate) async {
    await _audioPlayer.setSpeed(rate);
    _playerStore.setPlayRate(rate);
    _settingStore.setSpeed(rate);
  }

  /// 释放资源
  void dispose() {
    _progressManager.dispose();
    _audioPlayer.dispose();
  }
}
