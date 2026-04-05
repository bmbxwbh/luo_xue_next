import '../../models/play_music_info.dart';
import '../../models/song_model.dart';
import '../../store/player_store.dart';
import '../../utils/format_util.dart';

/// 播放信息管理 — 对齐 LX Music core/player/playInfo.ts
class PlayInfoManager {
  final PlayerStore _playerStore;

  PlayInfoManager(this._playerStore);

  /// 设置当前播放歌曲的详细信息（封面、歌词等基础信息）
  void setMusicInfo({
    String? id,
    String? name,
    String? singer,
    String? album,
    String? pic,
    String? lrc,
    String? tlrc,
    String? rlyrc,
    String? lxlyric,
    String? rawlrc,
  }) {
    _playerStore.patchMusicInfo(
      id: id,
      name: name,
      singer: singer,
      album: album,
      pic: pic,
      lrc: lrc,
      tlrc: tlrc,
      rlyrc: rlyrc,
      lxlyric: lxlyric,
      rawlrc: rawlrc,
    );
  }

  /// 重置音乐信息
  void resetMusicInfo() {
    _playerStore.setMusicInfo(const MusicInfo());
  }

  /// 设置播放音乐信息（关联列表ID）
  void setPlayMusicInfo(String? listId, SongModel? musicInfo, {bool isTempPlay = false}) {
    if (musicInfo != null) {
      _playerStore.setPlayMusicInfo(PlayMusicInfo(
        musicInfo: musicInfo,
        listId: listId ?? '',
        isTempPlay: isTempPlay,
      ));
      // 设置基础音乐信息
      setMusicInfo(
        id: musicInfo.id,
        name: musicInfo.name,
        singer: musicInfo.singer,
        album: musicInfo.albumName,
        pic: musicInfo.displayImg,
      );
    } else {
      _playerStore.setPlayMusicInfo(null);
      resetMusicInfo();
    }

    // 重置进度
    _playerStore.setProgressDirectly(0, 0);

    if (musicInfo == null) {
      _playerStore.updatePlayIndex(-1, -1);
      _playerStore.setPlayListId(null);
    } else {
      final indexInfo = _getPlayIndex(listId, musicInfo, isTempPlay);
      _playerStore.updatePlayIndex(indexInfo['playIndex']!, indexInfo['playerPlayIndex']!);
    }
  }

  /// 获取当前播放歌曲的索引
  Map<String, int> _getPlayIndex(String? listId, SongModel musicInfo, bool isTempPlay) {
    final playInfo = _playerStore.playInfo;
    final playerList = _getListMusics(playInfo.playerListId);

    int playIndex = -1;
    int playerPlayIndex = -1;

    if (playerList.isNotEmpty) {
      playerPlayIndex = playInfo.playerPlayIndex.clamp(0, playerList.length - 1);
    }

    final list = _getListMusics(listId);
    if (list.isNotEmpty) {
      playIndex = list.indexWhere((m) => m.id == musicInfo.id);
      if (!isTempPlay) {
        if (playIndex < 0) {
          playerPlayIndex = playerPlayIndex < 1 ? (list.length - 1) : (playerPlayIndex - 1);
        } else {
          playerPlayIndex = playIndex;
        }
      }
    }

    return {'playIndex': playIndex, 'playerPlayIndex': playerPlayIndex};
  }

  /// 获取列表内的歌曲（需要外部注入）
  List<SongModel> Function(String?)? _getListMusicsFn;
  void setListMusicsProvider(List<SongModel> Function(String?) provider) {
    _getListMusicsFn = provider;
  }

  List<SongModel> _getListMusics(String? listId) {
    if (_getListMusicsFn == null || listId == null) return [];
    return _getListMusicsFn!(listId);
  }

  /// 获取当前播放音乐信息
  PlayMusicInfo? getCurrentMusic() {
    return _playerStore.playMusicInfo;
  }
}
