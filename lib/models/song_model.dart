import 'enums.dart';

/// 音质信息 — 对齐 LX Music MusicQualityType
class MusicType {
  final String type; // "128k", "320k", "flac", "flac24bit"
  final String? size; // "3.56M"
  final String? hash; // 酷狗专用

  const MusicType({required this.type, this.size, this.hash});

  Map<String, dynamic> toJson() => {
        'type': type,
        if (size != null) 'size': size,
        if (hash != null) 'hash': hash,
      };

  factory MusicType.fromJson(Map<String, dynamic> json) {
    return MusicType(
      type: json['type'] ?? '128k',
      size: json['size'],
      hash: json['hash'],
    );
  }
}

/// 歌曲元信息基类 — 对齐 LX Music MusicInfoMetaBase
class MusicInfoMeta {
  final String songId; // 歌曲ID，mg源为copyrightId
  final String albumName; // 专辑名称
  final String? picUrl; // 封面URL
  final List<MusicType> qualitys; // 可用音质列表
  final Map<String, MusicType> qualitysMap; // 音质Map
  final String? albumId; // 专辑ID

  // 酷狗专用
  final String? hash;

  // QQ音乐专用
  final String? strMediaMid;
  final String? albumMid;

  // 咪咕专用
  final String? copyrightId;
  final String? lrcUrl;
  final String? mrcUrl;
  final String? trcUrl;

  const MusicInfoMeta({
    required this.songId,
    required this.albumName,
    this.picUrl,
    this.qualitys = const [],
    this.qualitysMap = const {},
    this.albumId,
    this.hash,
    this.strMediaMid,
    this.albumMid,
    this.copyrightId,
    this.lrcUrl,
    this.mrcUrl,
    this.trcUrl,
  });

  /// 排序后的音质列表 (高到低)
  List<Quality> get qualityList {
    final order = ['flac24bit', 'flac', 'wav', 'ape', '320k', '192k', '128k'];
    return qualitys
        .map((t) => Quality.fromString(t.type))
        .toList()
      ..sort((a, b) => order.indexOf(a.value).compareTo(order.indexOf(b.value)));
  }

  /// 最高可用音质
  Quality? get bestQuality => qualityList.isNotEmpty ? qualityList.first : null;

  Map<String, dynamic> toJson() => {
        'songId': songId,
        'albumName': albumName,
        'picUrl': picUrl,
        'qualitys': qualitys.map((t) => t.toJson()).toList(),
        'albumId': albumId,
        'hash': hash,
        'strMediaMid': strMediaMid,
        'albumMid': albumMid,
        'copyrightId': copyrightId,
        'lrcUrl': lrcUrl,
        'mrcUrl': mrcUrl,
        'trcUrl': trcUrl,
      };

  factory MusicInfoMeta.fromJson(Map<String, dynamic> json) {
    final qualitys = <MusicType>[];
    if (json['qualitys'] is List) {
      for (final q in json['qualitys'] as List) {
        if (q is Map<String, dynamic>) {
          qualitys.add(MusicType.fromJson(q));
        }
      }
    }
    final qualitysMap = <String, MusicType>{};
    for (final q in qualitys) {
      qualitysMap[q.type] = q;
    }
    return MusicInfoMeta(
      songId: json['songId']?.toString() ?? '',
      albumName: json['albumName'] ?? '',
      picUrl: json['picUrl'],
      qualitys: qualitys,
      qualitysMap: qualitysMap,
      albumId: json['albumId']?.toString(),
      hash: json['hash'],
      strMediaMid: json['strMediaMid'],
      albumMid: json['albumMid'],
      copyrightId: json['copyrightId'],
      lrcUrl: json['lrcUrl'],
      mrcUrl: json['mrcUrl'],
      trcUrl: json['trcUrl'],
    );
  }
}

/// 歌曲模型 — 完全对齐 LX Music 的 MusicInfoOnline 格式
class SongModel {
  final String id; // 唯一ID: source_songmid
  final String name; // 歌曲名
  final String singer; // 艺术家名
  final MusicSource source; // 音乐源
  final String interval; // 格式化时长 "03:55"
  final int intervalSec; // 秒数
  final MusicInfoMeta meta; // 元信息
  final String? localPath; // 本地文件路径

  const SongModel({
    required this.id,
    required this.name,
    required this.singer,
    required this.source,
    this.interval = '',
    this.intervalSec = 0,
    required this.meta,
    this.localPath,
  });

  /// 歌曲mid (从id中提取)
  String get songmid {
    final parts = id.split('_');
    return parts.length > 1 ? parts.sublist(1).join('_') : id;
  }

  /// 封面原始路径（用于 musicInfo 传递给脚本）
  String? get img => meta.picUrl;

  /// 封面显示URL（自动加前缀，用于 UI 显示）
  String? get displayImg {
    final raw = meta.picUrl;
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    // MG 源需要加前缀
    if (source.id == 'mg') return 'http://d.musicapp.migu.cn$raw';
    return raw;
  }

  /// 专辑名
  String get albumName => meta.albumName;

  /// 专辑ID
  String? get albumId => meta.albumId;

  /// 酷狗hash
  String? get hash => meta.hash;

  /// 咪咕copyrightId
  String? get copyrightId => meta.copyrightId;

  /// 可用音质列表
  List<Quality> get qualityList => meta.qualityList;

  /// 最高可用音质
  Quality? get bestQuality => meta.bestQuality;

  /// 兼容旧格式 — 从旧JSON创建
  factory SongModel.fromLxJson(Map<String, dynamic> json, MusicSource source) {
    final types = <MusicType>[];
    final typesMap = <String, MusicType>{};

    if (json['types'] is List) {
      for (final t in json['types'] as List) {
        final mt = MusicType(
          type: t['type'] ?? '128k',
          size: t['size'],
          hash: t['hash'],
        );
        types.add(mt);
        typesMap[mt.type] = mt;
      }
    }

    // 解析时长
    final interval = json['interval']?.toString() ?? '';
    final intervalSec = json['_interval'] is int
        ? json['_interval']
        : int.tryParse(json['_interval']?.toString() ?? '') ?? 0;

    final songmid = json['songmid']?.toString() ?? '';
    final id = '${source.id}_$songmid';

    final meta = MusicInfoMeta(
      songId: json['songId']?.toString() ?? songmid,
      albumName: json['albumName'] ?? '',
      picUrl: json['img'] ?? json['picUrl'],
      qualitys: types,
      qualitysMap: typesMap,
      albumId: json['albumId']?.toString(),
      hash: json['hash'],
      strMediaMid: json['strMediaMid'],
      albumMid: json['albumMid'],
      copyrightId: json['copyrightId'],
    );

    return SongModel(
      id: id,
      name: json['name'] ?? '',
      singer: json['singer'] ?? '',
      source: source,
      interval: interval,
      intervalSec: intervalSec,
      meta: meta,
    );
  }

  /// 从标准 LX Music 格式创建
  factory SongModel.fromLxMusicInfo(Map<String, dynamic> json) {
    final sourceId = json['source'] ?? 'kw';
    final source = MusicSource.fromId(sourceId);
    final id = json['id']?.toString() ?? '';

    // 解析 meta
    final metaJson = json['meta'] as Map<String, dynamic>? ?? {};
    final qualitys = <MusicType>[];
    if (metaJson['qualitys'] is List) {
      for (final q in metaJson['qualitys'] as List) {
        if (q is Map<String, dynamic>) {
          qualitys.add(MusicType.fromJson(q));
        }
      }
    }
    final qualitysMap = <String, MusicType>{};
    for (final q in qualitys) {
      qualitysMap[q.type] = q;
    }

    final meta = MusicInfoMeta(
      songId: metaJson['songId']?.toString() ?? '',
      albumName: metaJson['albumName'] ?? '',
      picUrl: metaJson['picUrl'],
      qualitys: qualitys,
      qualitysMap: qualitysMap,
      albumId: metaJson['albumId']?.toString(),
      hash: metaJson['hash'],
      strMediaMid: metaJson['strMediaMid'],
      albumMid: metaJson['albumMid'],
      copyrightId: metaJson['copyrightId'],
    );

    // 解析 interval
    final interval = json['interval']?.toString() ?? '';
    int intervalSec = 0;
    if (interval.contains(':')) {
      final parts = interval.split(':');
      if (parts.length == 2) {
        intervalSec = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
      }
    }

    return SongModel(
      id: id,
      name: json['name'] ?? '',
      singer: json['singer'] ?? '',
      source: source,
      interval: interval,
      intervalSec: intervalSec,
      meta: meta,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'singer': singer,
        'source': source.id,
        'interval': interval,
        'meta': meta.toJson(),
      };

  factory SongModel.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('meta')) {
      return SongModel.fromLxMusicInfo(json);
    }
    final source = MusicSource.fromId(json['source'] ?? 'kw');
    return SongModel.fromLxJson(json, source);
  }

  /// 复制并修改部分字段
  SongModel copyWith({
    String? name,
    String? singer,
    String? interval,
    int? intervalSec,
    MusicInfoMeta? meta,
  }) {
    return SongModel(
      id: id,
      name: name ?? this.name,
      singer: singer ?? this.singer,
      source: source,
      interval: interval ?? this.interval,
      intervalSec: intervalSec ?? this.intervalSec,
      meta: meta ?? this.meta,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SongModel && other.id == id);

  @override
  int get hashCode => id.hashCode;

  /// 转换为洛雪音乐源插件需要的 musicInfo 格式
  /// 对齐洛雪原版格式 — 字段名、字段顺序、值必须完全一致
  Map<String, dynamic> toMusicInfoJson() {
    // 构建 types 列表
    final types = meta.qualitys.map((t) => {
      'type': t.type,
      if (t.size != null) 'size': t.size,
    }).toList();

    // 构建 _types map
    final typesMap = <String, dynamic>{};
    for (final t in meta.qualitys) {
      typesMap[t.type] = {if (t.size != null) 'size': t.size};
    }

    // 字段顺序严格对齐洛雪原版: singer, name, albumName, albumId, songmid, copyrightId, source, interval, img, lrc, lrcUrl, mrcUrl, trcUrl, otherSource, types, _types, typeUrl
    final map = <String, dynamic>{
      'singer': singer,
      'name': name,
      'albumName': albumName,
      'albumId': meta.albumId,
      'songmid': songmid,
    };

    // copyrightId 追加在 songmid 后面（和原项目一致）
    if (source.id == 'mg' && meta.copyrightId != null) map['copyrightId'] = meta.copyrightId;
    if (source.id == 'kg' && meta.hash != null) map['hash'] = meta.hash;
    if (source.id == 'tx' && meta.strMediaMid != null) map['strMediaMid'] = meta.strMediaMid;
    if (source.id == 'tx' && meta.albumMid != null) map['albumMid'] = meta.albumMid;

    map['source'] = source.id;
    map['interval'] = interval;
    map['img'] = img;
    // 对齐洛雪原版：保留 lrc 相关字段（用户脚本可能需要）
    if (source.id == 'mg' && meta.lrcUrl != null) map['lrcUrl'] = meta.lrcUrl;
    if (source.id == 'mg' && meta.mrcUrl != null) map['mrcUrl'] = meta.mrcUrl;
    if (source.id == 'mg' && meta.trcUrl != null) map['trcUrl'] = meta.trcUrl;
    // lrc 字段保留为 null（对齐原项目）
    map['lrc'] = null;
    map['types'] = types;
    map['_types'] = typesMap;
    map['typeUrl'] = <String, dynamic>{};

    return map;
  }

  /// 输出为 JS 对象字面量格式（对齐洛雪 sign 计算用的字符串）
  /// 格式：{name:'过春痕',singer:'银临',...} — 单引号、无引号键名
  String toMusicInfoJsString() {
    final buf = StringBuffer('{');

    void writeValue(dynamic v) {
      if (v == null) {
        buf.write('null');
      } else if (v is String) {
        buf.write("'");
        buf.write(v.replaceAll("'", "\\'"));
        buf.write("'");
      } else if (v is num || v is bool) {
        buf.write(v);
      } else if (v is List) {
        buf.write('[');
        for (int i = 0; i < v.length; i++) {
          if (i > 0) buf.write(',');
          writeValue(v[i]);
        }
        buf.write(']');
      } else if (v is Map) {
        buf.write('{');
        bool first = true;
        for (final entry in v.entries) {
          if (!first) buf.write(',');
          buf.write(entry.key); // 键名无引号
          buf.write(':');
          writeValue(entry.value);
          first = false;
        }
        buf.write('}');
      } else {
        buf.write("'");
        buf.write(v.toString().replaceAll("'", "\\'"));
        buf.write("'");
      }
    }

    final map = toMusicInfoJson();
    bool first = true;
    for (final entry in map.entries) {
      if (!first) buf.write(',');
      buf.write(entry.key); // 键名无引号
      buf.write(':');
      writeValue(entry.value);
      first = false;
    }

    buf.write('}');
    return buf.toString();
  }
}
