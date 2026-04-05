import 'dart:convert';
import '../models/enums.dart';
import '../models/song_model.dart';
import '../store/list_store.dart';
import 'music/online.dart';

/// 用户歌单管理 — 对齐 LX Music core/list.dart
class ListManager {
  final ListStore _listStore;

  ListManager(this._listStore);

  /// 创建歌单
  void createList(String name, {String? id}) {
    final listId = id ?? 'userlist_${DateTime.now().millisecondsSinceEpoch}';
    _listStore.addUserList(UserListInfo(
      id: listId,
      name: name,
    ));
  }

  /// 删除歌单
  void deleteList(String listId) {
    _listStore.removeUserList(listId);
  }

  /// 批量删除歌单
  void deleteLists(List<String> ids) {
    _listStore.removeUserLists(ids);
  }

  /// 重命名歌单
  void renameList(String listId, String newName) {
    final list = _listStore.userList.firstWhere(
      (l) => l.id == listId,
      orElse: () => UserListInfo(id: '', name: ''),
    );
    if (list.id.isNotEmpty) {
      _listStore.updateUserList(list.copyWith(name: newName));
    }
  }

  /// 添加歌曲到歌单
  void addMusicToList(String listId, SongModel music, {bool addToTop = true}) {
    _listStore.addMusicsToList(listId, [music], addToTop: addToTop);
  }

  /// 批量添加歌曲到歌单
  void addMusicsToList(String listId, List<SongModel> musics, {bool addToTop = true}) {
    _listStore.addMusicsToList(listId, musics, addToTop: addToTop);
  }

  /// 从歌单移除歌曲
  void removeMusicFromList(String listId, String musicId) {
    _listStore.removeMusicFromList(listId, musicId);
  }

  /// 批量从歌单移除歌曲
  void removeMusicsFromList(String listId, List<String> musicIds) {
    _listStore.removeMusicsFromList(listId, musicIds);
  }

  /// 移动歌曲位置
  void moveMusic(String listId, int fromIndex, int toIndex) {
    _listStore.moveMusicInList(listId, fromIndex, toIndex);
  }

  /// 跨列表移动歌曲
  void moveMusicBetweenLists(String fromListId, String toListId, String musicId) {
    final fromList = _listStore.getListMusics(fromListId);
    final music = fromList.firstWhere(
      (m) => m.id == musicId,
      orElse: () => throw Exception('Music not found'),
    );
    _listStore.removeMusicFromList(fromListId, musicId);
    _listStore.addMusicsToList(toListId, [music], addToTop: true);
  }

  /// 导入歌单
  void importList(String json, {String? name}) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final listId = data['id'] as String? ?? 'userlist_${DateTime.now().millisecondsSinceEpoch}';
      final listName = name ?? data['name'] as String? ?? '导入歌单';
      final songsJson = data['list'] as List? ?? [];

      final songs = songsJson
          .whereType<Map<String, dynamic>>()
          .map((j) => SongModel.fromJson(j))
          .toList();

      _listStore.addUserList(UserListInfo(id: listId, name: listName));
      _listStore.setListMusics(listId, songs);
    } catch (e) {
      print('importList error: $e');
    }
  }

  /// 导出歌单
  String exportList(String listId) {
    final songs = _listStore.getListMusics(listId);
    final listInfo = _listStore.userList.firstWhere(
      (l) => l.id == listId,
      orElse: () => UserListInfo(id: listId, name: '未命名'),
    );

    final data = {
      'id': listId,
      'name': listInfo.name,
      'list': songs.map((s) => s.toJson()).toList(),
    };

    return jsonEncode(data);
  }

  /// 收藏歌曲
  void collectMusic(SongModel music) {
    _listStore.addMusicsToList(ListIds.love, [music], addToTop: true);
  }

  /// 取消收藏
  void uncollectMusic(String musicId) {
    _listStore.removeMusicFromList(ListIds.love, musicId);
  }

  /// 检查歌曲是否已收藏
  bool isMusicCollected(String musicId) {
    final loveList = _listStore.getListMusics(ListIds.love);
    return loveList.any((m) => m.id == musicId);
  }

  /// 获取歌单歌曲数
  int getListCount(String listId) {
    return _listStore.getListMusics(listId).length;
  }

  /// 清空歌单
  void clearList(String listId) {
    _listStore.clearListMusics(listId);
  }

  /// 设置当前激活的歌单
  void setActiveList(String listId) {
    _listStore.setActiveList(listId);
  }

  /// 获取当前激活的歌单
  String get activeListId => _listStore.activeListId;

  /// 获取所有用户歌单
  List<UserListInfo> get userLists => _listStore.userList;
}
