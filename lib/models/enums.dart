/// 音质类型 — 对齐 LX Music
enum Quality {
  k128('128k'),
  k192('192k'),
  k320('320k'),
  flac('flac'),
  flac24bit('flac24bit'),
  ape('ape'),
  wav('wav');

  const Quality(this.value);
  final String value;

  static Quality fromString(String value) {
    return Quality.values.firstWhere(
      (q) => q.value == value,
      orElse: () => Quality.k128,
    );
  }
}

/// 音乐源 — 对齐 LX Music
enum MusicSource {
  kw('kw', '酷我音乐'),
  kg('kg', '酷狗音乐'),
  tx('tx', 'QQ音乐'),
  wy('wy', '网易云音乐'),
  mg('mg', '咪咕音乐'),
  local('local', '本地音乐');

  const MusicSource(this.id, this.name);
  final String id;
  final String name;

  static MusicSource fromId(String id) {
    return MusicSource.values.firstWhere(
      (s) => s.id == id,
      orElse: () => MusicSource.tx,
    );
  }
}

/// 播放模式 — 对齐 LX Music
enum PlayMode {
  listLoop('listLoop'),   // 列表循环
  singleLoop('singleLoop'), // 单曲循环
  random('random'),       // 随机播放
  list('list');           // 顺序播放（播放完停止）

  const PlayMode(this.value);
  final String value;

  static PlayMode fromString(String value) {
    return PlayMode.values.firstWhere(
      (m) => m.value == value,
      orElse: () => PlayMode.listLoop,
    );
  }
}

/// 列表类型 — 对齐 LX Music
enum ListType {
  defaultList('default', '试听列表'),
  love('love', '我的收藏'),
  temp('temp', '临时列表'),
  download('download', '下载列表');

  const ListType(this.id, this.name);
  final String id;
  final String name;

  static ListType fromId(String id) {
    return ListType.values.firstWhere(
      (t) => t.id == id,
      orElse: () => ListType.defaultList,
    );
  }
}
