import "enums.dart";
import 'song_model.dart';

/// 播放信息 — 对齐 LX Music Player.PlayMusicInfo
class PlayMusicInfo {
  /// 当前播放歌曲信息
  final SongModel musicInfo;

  /// 当前播放歌曲的列表ID
  final String listId;

  /// 是否属于"稍后播放"
  final bool isTempPlay;

  const PlayMusicInfo({
    required this.musicInfo,
    required this.listId,
    this.isTempPlay = false,
  });

  /// 歌曲ID
  String get musicId => musicInfo.id;

  /// 歌曲名
  String get name => musicInfo.name;

  /// 歌手名
  String get singer => musicInfo.singer;

  /// 封面URL
  String? get pic => musicInfo.displayImg;

  /// 专辑名
  String get album => musicInfo.albumName;

  /// 音乐源
  MusicSource get source => musicInfo.source;

  /// 复制并修改
  PlayMusicInfo copyWith({
    SongModel? musicInfo,
    String? listId,
    bool? isTempPlay,
  }) {
    return PlayMusicInfo(
      musicInfo: musicInfo ?? this.musicInfo,
      listId: listId ?? this.listId,
      isTempPlay: isTempPlay ?? this.isTempPlay,
    );
  }

  Map<String, dynamic> toJson() => {
        'musicInfo': musicInfo.toJson(),
        'listId': listId,
        'isTempPlay': isTempPlay,
      };

  factory PlayMusicInfo.fromJson(Map<String, dynamic> json) {
    return PlayMusicInfo(
      musicInfo: SongModel.fromJson(json['musicInfo'] as Map<String, dynamic>),
      listId: json['listId'] ?? '',
      isTempPlay: json['isTempPlay'] ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayMusicInfo &&
          other.musicInfo == musicInfo &&
          other.listId == listId &&
          other.isTempPlay == isTempPlay);

  @override
  int get hashCode => Object.hash(musicInfo, listId, isTempPlay);
}
