import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../models/enums.dart';
import '../store/player_store.dart';
import '../services/music/list_store.dart';
import '../utils/format_util.dart';
import '../utils/global.dart';

/// 歌曲列表项
class SongListTile extends StatelessWidget {
  final SongModel song;
  final int index;
  final VoidCallback? onTap;
  final String? listId;

  const SongListTile({
    super.key,
    required this.song,
    required this.index,
    this.onTap,
    this.listId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playerStore = context.watch<PlayerStore>();
    final isPlaying = playerStore.playMusicInfo?.musicId == song.id;

    return ListTile(
      leading: _buildLeading(context, isPlaying),
      title: Text(
        FormatUtil.decodeName(song.name),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isPlaying ? theme.colorScheme.primary : null,
          fontWeight: isPlaying ? FontWeight.bold : null,
        ),
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              '${FormatUtil.formatSingerName(song.singer)} - ${FormatUtil.decodeName(song.albumName)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (song.interval.isNotEmpty)
            Text(
              song.interval,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      trailing: _buildTrailing(context),
      onTap: onTap ?? () => _playSong(context),
      onLongPress: () => _showContextMenu(context),
    );
  }

  Widget _buildLeading(BuildContext context, bool isPlaying) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (song.displayImg != null && song.displayImg!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                song.displayImg!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildIndexBadge(context, isPlaying),
              ),
            )
          else
            _buildIndexBadge(context, isPlaying),
          if (isPlaying)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              ),
              child: Icon(
                Icons.play_arrow,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIndexBadge(BuildContext context, bool isPlaying) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: isPlaying
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Center(
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isPlaying
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget? _buildTrailing(BuildContext context) {
    final best = song.bestQuality;
    if (best == null) return null;

    final (label, color) = _qualityLabel(best);
    if (label.isEmpty) return null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  (String, Color) _qualityLabel(Quality q) {
    return switch (q) {
      Quality.flac24bit => ('Hi-Res', Colors.red),
      Quality.flac => ('FLAC', Colors.orange),
      Quality.ape => ('APE', Colors.orange),
      Quality.wav => ('WAV', Colors.orange),
      Quality.k320 => ('320K', Colors.blue),
      Quality.k192 => ('192K', Colors.green),
      Quality.k128 => ('128K', Colors.grey),
    };
  }

  void _playSong(BuildContext context) {
    globalPlayer.playMusic(song);
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('播放'),
              onTap: () {
                Navigator.pop(ctx);
                _playSong(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: const Text('稍后播放'),
              onTap: () {
                globalPlayer.playLater(song);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text('收藏'),
              onTap: () {
                final listStore = context.read<ListStore>();
                listStore.addSongToList('love', song.id);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已收藏')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('添加到歌单'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddToListDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('下载'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('下载功能开发中')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToListDialog(BuildContext context) {
    final listStore = context.read<ListStore>();
    final userLists = listStore.userLists;

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('添加到歌单'),
        children: [
          ...userLists.map((list) => SimpleDialogOption(
                onPressed: () {
                  listStore.addSongToList(list.id, song.id);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已添加到「${list.name}」')),
                  );
                },
                child: Text(list.name),
              )),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _showCreateAndAddDialog(context);
            },
            child: const Row(
              children: [
                Icon(Icons.add_circle_outline),
                SizedBox(width: 8),
                Text('新建歌单'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateAndAddDialog(BuildContext context) {
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
                final listStore = context.read<ListStore>();
                listStore.createList(name);
                // 新创建的歌单ID以 list_ 开头
                final newList = listStore.userLists.last;
                listStore.addSongToList(newList.id, song.id);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已创建并添加到「$name」')),
                );
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}
