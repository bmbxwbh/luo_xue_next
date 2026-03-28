/// 用户歌单 — 对齐 LX Music UserListInfo
class UserList {
  /// 歌单ID
  final String id;

  /// 歌单名称
  final String name;

  /// 歌曲ID列表
  final List<String> musicIds;

  /// 是否为默认歌单（不可删除）
  final bool isDefault;

  /// 关联的源（可选）
  final String? source;

  /// 源歌单ID（可选）
  final String? sourceListId;

  /// 位置更新时间
  final int? locationUpdateTime;

  const UserList({
    required this.id,
    required this.name,
    this.musicIds = const [],
    this.isDefault = false,
    this.source,
    this.sourceListId,
    this.locationUpdateTime,
  });

  /// 歌曲数量
  int get musicCount => musicIds.length;

  /// 是否为空
  bool get isEmpty => musicIds.isEmpty;

  /// 创建默认歌单（试听列表）
  factory UserList.defaultList() {
    return const UserList(
      id: 'default',
      name: '试听列表',
      isDefault: true,
    );
  }

  /// 创建收藏歌单
  factory UserList.loveList() {
    return const UserList(
      id: 'love',
      name: '我的收藏',
      isDefault: true,
    );
  }

  /// 创建临时列表
  factory UserList.tempList() {
    return const UserList(
      id: 'temp',
      name: '临时列表',
      isDefault: true,
    );
  }

  /// 添加歌曲
  UserList addMusic(String musicId) {
    return UserList(
      id: id,
      name: name,
      musicIds: [...musicIds, musicId],
      isDefault: isDefault,
      source: source,
      sourceListId: sourceListId,
      locationUpdateTime: locationUpdateTime,
    );
  }

  /// 移除歌曲
  UserList removeMusic(String musicId) {
    return UserList(
      id: id,
      name: name,
      musicIds: musicIds.where((id) => id != musicId).toList(),
      isDefault: isDefault,
      source: source,
      sourceListId: sourceListId,
      locationUpdateTime: locationUpdateTime,
    );
  }

  /// 批量添加
  UserList addMusics(List<String> ids) {
    return UserList(
      id: id,
      name: name,
      musicIds: [...musicIds, ...ids],
      isDefault: isDefault,
      source: source,
      sourceListId: sourceListId,
      locationUpdateTime: locationUpdateTime,
    );
  }

  /// 清空
  UserList clear() {
    return UserList(
      id: id,
      name: name,
      musicIds: [],
      isDefault: isDefault,
      source: source,
      sourceListId: sourceListId,
      locationUpdateTime: locationUpdateTime,
    );
  }

  /// 复制并修改
  UserList copyWith({
    String? name,
    List<String>? musicIds,
    String? source,
    String? sourceListId,
  }) {
    return UserList(
      id: id,
      name: name ?? this.name,
      musicIds: musicIds ?? this.musicIds,
      isDefault: isDefault,
      source: source ?? this.source,
      sourceListId: sourceListId ?? this.sourceListId,
      locationUpdateTime: locationUpdateTime,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'musicIds': musicIds,
        'isDefault': isDefault,
        'source': source,
        'sourceListId': sourceListId,
        'locationUpdateTime': locationUpdateTime,
      };

  factory UserList.fromJson(Map<String, dynamic> json) {
    return UserList(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      musicIds: json['musicIds'] is List
          ? (json['musicIds'] as List).map((e) => e.toString()).toList()
          : [],
      isDefault: json['isDefault'] ?? false,
      source: json['source'],
      sourceListId: json['sourceListId'],
      locationUpdateTime: json['locationUpdateTime'],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is UserList && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
