import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/player/player_service.dart';
import '../../services/music/list_store.dart';
import '../../models/lyric_info.dart';
import '../../utils/format_util.dart';
import '../../models/enums.dart';
import '../../models/play_music_info.dart';

/// 播放详情页
class PlayDetailScreen extends StatefulWidget {
  const PlayDetailScreen({super.key});

  @override
  State<PlayDetailScreen> createState() => _PlayDetailScreenState();
}

class _PlayDetailScreenState extends State<PlayDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  bool _showLyrics = false;

  // 模拟歌词
  final LyricInfo _lyricInfo = LyricInfo(
    lyric: '''[00:00.00] 歌曲名 - 歌手名
[00:05.00] 这是一首示例歌词
[00:10.00] 洛雪音乐 Flutter 版
[00:15.00] 支持歌词滚动显示
[00:20.00] 点击封面切换歌词
[00:25.00] 可以控制播放进度
[00:30.00] 支持多种播放模式
[00:35.00] 收藏喜欢的歌曲
[00:40.00] 创建自定义歌单
[00:45.00] 支持多音源搜索
[00:50.00] 享受音乐的快乐
[00:55.00] ...
[01:00.00] 间奏...
[01:15.00] 第二段歌词开始
[01:20.00] 继续展示滚动效果
[01:25.00] 每行歌词对应时间戳
[01:30.00] 自动高亮当前行
[01:35.00] ...
''',
  );

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final info = player.playInfo;

    if (info == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('播放详情')),
        body: const Center(child: Text('暂无播放歌曲')),
      );
    }

    if (player.isPlaying) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部栏
              _buildAppBar(player, info),
              // 主内容
              Expanded(
                child: _showLyrics
                    ? _buildLyrics(player)
                    : _buildCover(info.musicInfo.displayImg),
              ),
              // 控制区
              _buildControls(player),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(PlayerService player, PlayMusicInfo info) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  FormatUtil.decodeName(info.musicInfo.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  FormatUtil.formatSingerName(info.musicInfo.singer),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () => _showMoreOptions(),
          ),
        ],
      ),
    );
  }

  Widget _buildCover(String? imgUrl) {
    final tag = imgUrl != null && imgUrl.isNotEmpty ? 'mini_cover_$imgUrl' : 'mini_cover_empty';
    return GestureDetector(
      onTap: () => setState(() => _showLyrics = true),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Hero(
            tag: tag,
            child: RotationTransition(
              turns: _rotationController,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: imgUrl != null && imgUrl.isNotEmpty
                      ? Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.music_note,
                            size: 80,
                          ),
                        )
                      : const Icon(Icons.music_note, size: 80),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLyrics(PlayerService player) {
    final lines = _lyricInfo.parseLrc();
    final currentPos = player.position.inMilliseconds / 1000.0;

    // 找到当前歌词行
    int currentLine = 0;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (currentPos >= lines[i].time) {
        currentLine = i;
        break;
      }
    }

    return GestureDetector(
      onTap: () => setState(() => _showLyrics = false),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          final isCurrent = index == currentLine;
          return AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: isCurrent ? 20 : 16,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              height: 2.2,
            ),
            child: Text(line.text),
          );
        },
      ),
    );
  }

  Widget _buildControls(PlayerService player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // 进度条
          Row(
            children: [
              Text(player.positionStr, style: Theme.of(context).textTheme.bodySmall),
              Expanded(
                child: Slider(
                  value: player.progress.clamp(0.0, 1.0),
                  onChanged: (v) => player.seekTo(v),
                ),
              ),
              Text(player.durationStr, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          // 播放控制
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 播放模式
              IconButton(
                icon: Icon(_playModeIcon(player.playMode)),
                onPressed: () => player.togglePlayMode(),
              ),
              // 上一首
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 36),
                onPressed: () => player.playPrev(),
              ),
              // 播放/暂停
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: IconButton(
                  icon: Icon(
                    player.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 36,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: () => player.togglePlay(),
                ),
              ),
              // 下一首
              IconButton(
                icon: const Icon(Icons.skip_next, size: 36),
                onPressed: () => player.playNext(),
              ),
              // 播放列表
              IconButton(
                icon: const Icon(Icons.queue_music),
                onPressed: () => _showPlaylist(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 底部工具栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.favorite_border),
                onPressed: () => _addToFavorite(),
              ),
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('下载功能开发中')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('分享功能开发中')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  IconData _playModeIcon(PlayMode mode) {
    return switch (mode) {
      PlayMode.listLoop => Icons.repeat,
      PlayMode.singleLoop => Icons.repeat_one,
      PlayMode.random => Icons.shuffle,
      PlayMode.list => Icons.playlist_play,
    };
  }

  void _addToFavorite() {
    try {
      final player = context.read<PlayerService>();
      final info = player.playInfo;
      if (info != null) {
        context.read<ListStore>().addSongToList('love', info.musicInfo.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已收藏')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('收藏失败: $e')),
      );
    }
  }

  void _showPlaylist() {
    showModalBottomSheet(
      context: context,
      builder: (_) => const SizedBox(
        height: 300,
        child: Center(child: Text('播放列表 - 开发中')),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('歌曲信息'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.lyrics),
              title: const Text('歌词设置'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
