import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/user_list.dart';
import '../../models/song_model.dart';
import '../../models/enums.dart';
import '../../services/music/list_store.dart';
import '../../services/music/local_music_service.dart';
import '../../services/player/player_service.dart';
import '../../store/player_store.dart';
import '../../store/list_store.dart' as app_store;
import '../../widgets/song_list_tile.dart';

enum SortType {
  addTime('按添加时间'),
  songName('按歌曲名'),
  singerName('按歌手名');

  final String label;
  const SortType(this.label);
}

/// 我的歌单 Tab
class TabMyList extends StatefulWidget {
  const TabMyList({super.key});

  @override
  State<TabMyList> createState() => _TabMyListState();
}

class _TabMyListState extends State<TabMyList> {
  String? _selectedListId;
  SortType _sortType = SortType.addTime;
  bool _batchMode = false;
  final Set<String> _selectedIds = {};
  List<SongModel> _sortedSongs = [];

  @override
  Widget build(BuildContext context) {
    final listStore = context.watch<ListStore>();
    final localService = context.watch<LocalMusicService>();

    // 选中了某个歌单
    if (_selectedListId != null) {
      if (_selectedListId == 'local') {
        return SafeArea(child: _buildLocalMusicView(localService));
      }
      final list = listStore.getList(_selectedListId!);
      if (list != null) return SafeArea(child: _buildSongListView(list, listStore));
    }

    return _buildOverview(listStore, localService);
  }

  Widget _buildOverview(ListStore listStore, LocalMusicService localService) {
    final playerStore = context.watch<PlayerStore>();
    final totalSongs = listStore.allLists.fold<int>(0, (sum, l) => sum + l.musicCount);
    final recentCount = playerStore.playedList.length;
    final favCount = listStore.loveList?.musicCount ?? 0;

    return SafeArea(
      child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        // 统计卡片
        _buildStatsCard(totalSongs, recentCount, favCount),
        const SizedBox(height: 12),
        // 本地音乐入口
        _buildFeatureTile(
          icon: Icons.library_music,
          title: '本地音乐',
          subtitle: '${localService.count} 首歌曲',
          color: Colors.blue,
          onTap: () => setState(() => _selectedListId = 'local'),
        ),
        const SizedBox(height: 8),
        // 最近播放入口
        _buildFeatureTile(
          icon: Icons.history,
          title: '最近播放',
          subtitle: '播放历史',
          color: Colors.orange,
          onTap: () {},
        ),
        const SizedBox(height: 8),
        // 我喜欢
        if (listStore.loveList != null)
          _buildFeatureTile(
            icon: Icons.favorite,
            title: listStore.loveList!.name,
            subtitle: '${listStore.loveList!.musicCount} 首歌曲',
            color: Colors.red,
            onTap: () => setState(() => _selectedListId = listStore.loveList!.id),
          ),
        const SizedBox(height: 16),
        // 系统歌单（isDefault=true，排除 love）
        ..._buildPlaylistSection(
          title: '系统歌单',
          lists: listStore.allLists.where((l) => l.isDefault && l.id != 'love').toList(),
          listStore: listStore,
        ),
        const SizedBox(height: 16),
        // 我的歌单（isDefault=false）
        Row(
          children: [
            Text(
              '我的歌单',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: '新建歌单',
              onPressed: () => _showCreateListDialog(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...listStore.userLists.map(
          (list) => _buildListTile(list, listStore),
        ),
        const SizedBox(height: 80),
      ],
    ),
    );
  }

  List<Widget> _buildPlaylistSection({
    required String title,
    required List<UserList> lists,
    required ListStore listStore,
  }) {
    if (lists.isEmpty) return [];
    return [
      Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
      const SizedBox(height: 8),
      ...lists.map((list) => _buildListTile(list, listStore)),
    ];
  }

  Widget _buildStatsCard(int totalSongs, int recentCount, int favCount) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildStatItem(totalSongs.toString(), '总歌曲数', Colors.blue),
          Container(width: 1, height: 32, color: colorScheme.outlineVariant),
          _buildStatItem(recentCount.toString(), '最近播放', Colors.orange),
          Container(width: 1, height: 32, color: colorScheme.outlineVariant),
          _buildStatItem(favCount.toString(), '收藏数', Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(30),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onTap: onTap,
    );
  }

  Widget _buildListTile(UserList list, ListStore listStore) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: const Icon(Icons.folder, size: 20),
      ),
      title: Text(list.name),
      subtitle: Text('${list.musicCount} 首歌曲'),
      trailing: list.isDefault
          ? null
          : PopupMenuButton<String>(
              onSelected: (action) => _handleListAction(action, list, listStore),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'rename', child: Text('重命名')),
                const PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
      onTap: () => setState(() => _selectedListId = list.id),
    );
  }

  /// 本地音乐视图
  Widget _buildLocalMusicView(LocalMusicService localService) {
    final songs = localService.songs;

    return Column(
      children: [
        // 头部
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.withAlpha(40),
                Theme.of(context).colorScheme.surface,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedListId = null),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '本地音乐',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${songs.length} 首歌曲',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              // 扫描按钮
              IconButton(
                icon: localService.scanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                tooltip: '扫描本地音乐',
                onPressed: localService.scanning
                    ? null
                    : () async {
                        final count = await localService.scanLocalMusic();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('扫描完成，找到 $count 首歌曲')),
                          );
                        }
                      },
              ),
              // 手动导入
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: '导入音乐文件',
                onPressed: () => _importFiles(localService),
              ),
            ],
          ),
        ),
        // 歌曲列表
        Expanded(
          child: songs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.music_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('暂无本地音乐'),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('扫描本地音乐'),
                        onPressed: localService.scanning
                            ? null
                            : () async {
                                final count = await localService.scanLocalMusic();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('找到 $count 首歌曲')),
                                  );
                                }
                              },
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.file_open),
                        label: const Text('手动导入文件'),
                        onPressed: () => _importFiles(localService),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    return Dismissible(
                      key: ValueKey(songs[index].id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => localService.removeSong(songs[index].id),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withAlpha(30),
                          child: const Icon(Icons.music_note, size: 20),
                        ),
                        title: Text(songs[index].name),
                        subtitle: Text(songs[index].singer),
                        onTap: () {
                          final player = context.read<PlayerService>();
                          player.playSong(songs[index], listId: 'local');
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 歌单内歌曲视图
  Widget _buildSongListView(UserList list, ListStore listStore) {
    final appListStore = context.read<app_store.ListStore>();
    final songs = appListStore.getListMusics(list.id);
    
    _sortedSongs = _sortSongs(songs);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.surface,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      _exitBatchMode();
                      setState(() => _selectedListId = null);
                    },
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          list.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${list.musicCount} 首歌曲',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (!_batchMode) ...[
                    IconButton(
                      icon: const Icon(Icons.sort),
                      tooltip: '排序',
                      onPressed: () => _showSortMenu(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.playlist_add_check),
                      tooltip: '批量管理',
                      onPressed: () => setState(() => _batchMode = true),
                    ),
                  ] else
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: '退出批量模式',
                      onPressed: _exitBatchMode,
                    ),
                ],
              ),
              if (_batchMode)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Text('已选择 ${_selectedIds.length} 项'),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          if (_selectedIds.length == songs.length) {
                            setState(() => _selectedIds.clear());
                          } else {
                            setState(() => _selectedIds.addAll(songs.map((s) => s.id)));
                          }
                        },
                        child: Text(_selectedIds.length == songs.length ? '取消全选' : '全选'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: list.musicIds.isEmpty
              ? const Center(child: Text('歌单为空'))
              : _buildSongList(songs, listStore),
        ),
        if (_batchMode) _buildBatchActionBar(list, listStore),
      ],
    );
  }

  List<SongModel> _sortSongs(List<SongModel> songs) {
    final sorted = List<SongModel>.from(songs);
    switch (_sortType) {
      case SortType.addTime:
        break;
      case SortType.songName:
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortType.singerName:
        sorted.sort((a, b) => a.singer.compareTo(b.singer));
        break;
    }
    return sorted;
  }

  Widget _buildSongList(List<SongModel> songs, ListStore listStore) {
    if (songs.isEmpty) {
      return ListView.builder(
        itemCount: listStore.getList(_selectedListId!)?.musicIds.length ?? 0,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withAlpha(30),
              child: const Icon(Icons.music_note, size: 20),
            ),
            title: Text('歌曲 ${index + 1}'),
            subtitle: const Text('添加歌曲后显示详情'),
          );
        },
      );
    }

    return ListView.builder(
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return ListTile(
          leading: _batchMode
              ? Checkbox(
                  value: _selectedIds.contains(song.id),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedIds.add(song.id);
                      } else {
                        _selectedIds.remove(song.id);
                      }
                    });
                  },
                )
              : CircleAvatar(
                  backgroundColor: Colors.blue.withAlpha(30),
                  child: const Icon(Icons.music_note, size: 20),
                ),
          title: Text(song.name.isEmpty ? '歌曲 ${index + 1}' : song.name),
          subtitle: Text(song.singer.isEmpty ? '添加歌曲后显示详情' : song.singer),
          onTap: () {
            if (_batchMode) {
              setState(() {
                if (_selectedIds.contains(song.id)) {
                  _selectedIds.remove(song.id);
                } else {
                  _selectedIds.add(song.id);
                }
              });
            } else {
              final player = context.read<PlayerService>();
              player.playSong(song, listId: _selectedListId ?? 'default');
            }
          },
        );
      },
    );
  }

  void _exitBatchMode() {
    setState(() {
      _batchMode = false;
      _selectedIds.clear();
    });
  }

  Widget _buildBatchActionBar(UserList list, ListStore listStore) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除选中'),
                onPressed: _selectedIds.isEmpty ? null : () => _deleteSelected(list, listStore),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.drive_file_move_outline),
                label: const Text('移动到歌单'),
                onPressed: _selectedIds.isEmpty ? null : () => _showMoveToDialog(list, listStore),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('排序方式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...SortType.values.map((type) => RadioListTile<SortType>(
              title: Text(type.label),
              value: type,
              groupValue: _sortType,
              onChanged: (v) {
                if (v != null) {
                  setState(() => _sortType = v);
                  Navigator.pop(ctx);
                }
              },
            )),
          ],
        ),
      ),
    );
  }

  void _deleteSelected(UserList list, ListStore listStore) {
    final appListStore = context.read<app_store.ListStore>();
    for (final id in _selectedIds) {
      appListStore.removeMusicFromList(list.id, id);
    }
    _exitBatchMode();
  }

  void _showMoveToDialog(UserList list, ListStore listStore) {
    final appListStore = context.read<app_store.ListStore>();
    final targetLists = appListStore.allListIds.where((id) => id != list.id).toList();

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('移动到歌单', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: targetLists.map((targetId) {
                  final listName = targetId == appListStore.defaultListId 
                      ? appListStore.defaultListName 
                      : targetId == appListStore.loveListId 
                          ? appListStore.loveListName 
                          : targetId;
                  return ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(listName),
                    onTap: () {
                      final songsToMove = <SongModel>[];
                      final sourceSongs = appListStore.getListMusics(list.id);
                      for (final songId in _selectedIds) {
                        final song = sourceSongs.firstWhere(
                          (s) => s.id == songId,
                          orElse: () => SongModel(
                            id: songId, name: '', singer: '',
                            source: MusicSource.kw,
                            meta: MusicInfoMeta(songId: songId, albumName: '')));
                        songsToMove.add(song);
                        appListStore.removeMusicFromList(list.id, songId);
                      }
                      appListStore.addMusicsToList(targetId, songsToMove);
                      Navigator.pop(ctx);
                      _exitBatchMode();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已移动 ${_selectedIds.length} 首歌曲')),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateListDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建歌单'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '请输入歌单名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                context.read<ListStore>().createList(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _handleListAction(String action, UserList list, ListStore listStore) {
    switch (action) {
      case 'rename':
        _showRenameDialog(list, listStore);
      case 'delete':
        _showDeleteConfirm(list, listStore);
    }
  }

  void _showRenameDialog(UserList list, ListStore listStore) {
    final controller = TextEditingController(text: list.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名歌单'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                listStore.renameList(list.id, name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(UserList list, ListStore listStore) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除歌单'),
        content: Text('确定要删除「${list.name}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              listStore.removeList(list.id);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 手动导入音乐文件
  void _importFiles(LocalMusicService localService) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final files = result.files
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();
      localService.addFiles(files);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导入 ${files.length} 首歌曲')),
        );
      }
    }
  }
}
