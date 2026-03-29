import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/player/player_service.dart';
import '../../services/music/list_store.dart';
import '../../models/lyric_info.dart';
import '../../utils/format_util.dart';
import '../../utils/global.dart';
import '../../models/enums.dart';
import '../../models/play_music_info.dart';

/// 播放详情页 — 全新设计
class PlayDetailScreen extends StatefulWidget {
  const PlayDetailScreen({super.key});

  @override
  State<PlayDetailScreen> createState() => _PlayDetailScreenState();
}

class _PlayDetailScreenState extends State<PlayDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _showLyrics = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleLyrics() {
    setState(() => _showLyrics = !_showLyrics);
    if (_showLyrics) {
      _fadeController.forward();
    } else {
      _fadeController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final info = player.playInfo;
    final colorScheme = Theme.of(context).colorScheme;

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
              colorScheme.primaryContainer.withValues(alpha: 0.4),
              colorScheme.surfaceContainerLowest,
              colorScheme.surface,
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(player, info),
              // 主内容区（封面/歌词交叉淡入淡出）
              Expanded(
                child: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 400),
                  sizeCurve: Curves.easeInOut,
                  crossFadeState: _showLyrics
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: _buildCover(info.musicInfo.displayImg),
                  secondChild: _buildLyrics(player),
                ),
              ),
              _buildControls(player),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(PlayerService player, PlayMusicInfo info) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  FormatUtil.decodeName(info.musicInfo.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  FormatUtil.formatSingerName(info.musicInfo.singer),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _toggleLyrics,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 唱片外圈装饰
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: RotationTransition(
                  turns: _rotationController,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                        width: 8,
                      ),
                    ),
                    child: ClipOval(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          imgUrl != null && imgUrl.isNotEmpty
                              ? Image.network(
                                  imgUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildPlaceholder(),
                                )
                              : _buildPlaceholder(),
                          // 中心唱片孔
                          Center(
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorScheme.surface,
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 点击提示
              Text(
                '点击切换歌词',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.music_note,
          size: 80,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildLyrics(PlayerService player) {
    final colorScheme = Theme.of(context).colorScheme;
    final musicInfo = globalPlayerStore.musicInfo;
    final lyricInfo = LyricInfo(
      lyric: musicInfo.lrc ?? '',
      tlyric: musicInfo.tlrc,
      rlyric: musicInfo.rlyrc,
      lxlrc: musicInfo.lxlrc,
    );
    final lines = lyricInfo.parseLrc();
    final currentPos = player.position.inMilliseconds / 1000.0;

    if (lines.isEmpty) {
      return GestureDetector(
        onTap: _toggleLyrics,
        child: Center(
          child: Text(
            '暂无歌词',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    int currentLine = 0;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (currentPos >= lines[i].time) {
        currentLine = i;
        break;
      }
    }

    return GestureDetector(
      onTap: _toggleLyrics,
      child: Container(
        color: Colors.transparent,
        child: ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.surface,
                colorScheme.surface.withValues(alpha: 0.0),
                colorScheme.surface.withValues(alpha: 0.0),
                colorScheme.surface,
              ],
              stops: const [0.0, 0.15, 0.85, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstOut,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
            itemCount: lines.length,
            itemBuilder: (context, index) {
              final line = lines[index];
              final isCurrent = index == currentLine;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  vertical: isCurrent ? 10 : 6,
                  horizontal: isCurrent ? 16 : 0,
                ),
                decoration: isCurrent
                    ? BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  style: TextStyle(
                    fontSize: isCurrent ? 20 : 15,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                    color: isCurrent
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.45),
                    height: 1.6,
                    letterSpacing: isCurrent ? 0.5 : 0,
                  ),
                  child: Text(
                    line.text,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildControls(PlayerService player) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    player.positionStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                        elevation: 2,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                      activeTrackColor: colorScheme.primary,
                      inactiveTrackColor: colorScheme.primaryContainer,
                      thumbColor: colorScheme.primary,
                    ),
                    child: Slider(
                      value: player.progress.clamp(0.0, 1.0),
                      onChanged: (v) => player.seekTo(v),
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    player.durationStr,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // 播放控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 播放模式
              _buildControlBtn(
                icon: _playModeIcon(player.playMode),
                size: 24,
                onTap: () => player.togglePlayMode(),
              ),
              // 上一首
              _buildControlBtn(
                icon: Icons.skip_previous_rounded,
                size: 32,
                onTap: () => player.playPrev(),
              ),
              // 播放/暂停 — 主按钮
              GestureDetector(
                onTap: () => player.togglePlay(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primary.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      key: ValueKey(player.isPlaying),
                      size: 32,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
              // 下一首
              _buildControlBtn(
                icon: Icons.skip_next_rounded,
                size: 32,
                onTap: () => player.playNext(),
              ),
              // 播放列表
              _buildControlBtn(
                icon: Icons.queue_music_rounded,
                size: 24,
                onTap: () => _showPlaylist(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 底部工具栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildToolBtn(
                icon: Icons.favorite_border_rounded,
                label: '收藏',
                onTap: () => _addToFavorite(),
              ),
              _buildToolBtn(
                icon: Icons.download_rounded,
                label: '下载',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('下载功能开发中'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              _buildToolBtn(
                icon: Icons.share_rounded,
                label: '分享',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('分享功能开发中'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
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

  Widget _buildControlBtn({
    required IconData icon,
    required double size,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, size: size),
      ),
    );
  }

  Widget _buildToolBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _playModeIcon(PlayMode mode) {
    return switch (mode) {
      PlayMode.listLoop => Icons.repeat_rounded,
      PlayMode.singleLoop => Icons.repeat_one_rounded,
      PlayMode.random => Icons.shuffle_rounded,
      PlayMode.list => Icons.playlist_play_rounded,
    };
  }

  void _addToFavorite() {
    try {
      final player = context.read<PlayerService>();
      final info = player.playInfo;
      if (info != null) {
        context.read<ListStore>().addSongToList('love', info.musicInfo.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已收藏 ♡'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '播放列表',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Expanded(
              child: Center(child: Text('暂无更多歌曲')),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('歌曲信息'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.lyrics_outlined),
                title: const Text('歌词设置'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
