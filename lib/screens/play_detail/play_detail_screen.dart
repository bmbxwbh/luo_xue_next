import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/settings/setting_store.dart';
import '../../services/music/list_store.dart';
import '../../store/player_store.dart';
import '../../models/lyric_info.dart';
import '../../utils/format_util.dart';
import '../../utils/global.dart';
import '../../models/enums.dart';
import '../../models/play_music_info.dart';
import '../../core/search/music.dart';
import '../../store/search_store.dart';

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
    final store = context.watch<PlayerStore>();
    final playMusicInfo = store.playMusicInfo;
    final colorScheme = Theme.of(context).colorScheme;

    if (playMusicInfo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('播放详情')),
        body: const Center(child: Text('暂无播放歌曲')),
      );
    }

    if (store.isPlay) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
    }

    return Scaffold(
      body: Stack(
        children: [
          // 背景：封面模糊图片或渐变
          _buildBackground(playMusicInfo.musicInfo.displayImg, colorScheme),
          // 内容
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  colorScheme.surfaceContainerLowest.withValues(alpha: 0.8),
                  colorScheme.surface,
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildAppBar(playMusicInfo),
                  // 主内容区（封面/歌词交叉淡入淡出）
                  Expanded(
                    child: AnimatedCrossFade(
                      duration: const Duration(milliseconds: 400),
                      sizeCurve: Curves.easeInOut,
                      crossFadeState: _showLyrics
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: _buildCover(playMusicInfo.musicInfo.displayImg),
                      secondChild: _buildLyrics(),
                    ),
                  ),
                  _buildControls(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(String? imgUrl, ColorScheme colorScheme) {
    if (imgUrl != null && imgUrl.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: CachedNetworkImage(
              imageUrl: imgUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _buildGradientBackground(colorScheme),
            ),
          ),
          Container(
            color: Colors.black.withValues(alpha: 0.4),
          ),
        ],
      );
    }
    return _buildGradientBackground(colorScheme);
  }

  Widget _buildGradientBackground(ColorScheme colorScheme) {
    return Container(
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
    );
  }

  Widget _buildAppBar(PlayMusicInfo info) {
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
                  FormatUtil.decodeName(globalPlayerStore.playMusicInfo!.musicInfo.name),
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
                  FormatUtil.formatSingerName(globalPlayerStore.playMusicInfo!.musicInfo.singer),
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
            icon: const Icon(Icons.swap_horiz),
            tooltip: '换源',
            onPressed: () => _showSourceSwitcher(info),
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
                              ? CachedNetworkImage(
                                  imageUrl: imgUrl,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 600,
                                  errorWidget: (_, __, ___) => _buildPlaceholder(),
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

  Widget _buildLyrics() {
    final colorScheme = Theme.of(context).colorScheme;
    final musicInfo = globalPlayerStore.musicInfo;
    final lyricInfo = LyricInfo(
      lyric: musicInfo.lrc ?? '',
      tlyric: musicInfo.tlrc,
      rlyric: musicInfo.rlyrc,
      lxlyric: musicInfo.lxlyric,
    );
    final lines = lyricInfo.parseLrc();
    final currentPos = globalPlayerStore.progress.nowPlayTime;

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
              return GestureDetector(
                onDoubleTap: () {
                  globalPlayer.seekTo(Duration(milliseconds: (line.time * 1000).round()));
                },
                child: AnimatedContainer(
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
              ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = globalPlayerStore.progress;

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
                    progress.nowPlayTimeStr,
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
                      value: progress.progress.clamp(0.0, 1.0),
                      onChanged: (v) {
                        final maxMs = progress.maxPlayTime;
                        if (maxMs > 0) {
                          globalPlayer.seekTo(Duration(milliseconds: (maxMs * v * 1000).round()));
                        }
                      },
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    progress.maxPlayTimeStr,
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
                icon: _playModeIcon(globalSettingStore.playMode),
                size: 24,
                onTap: () => globalPlayer.togglePlayMode(),
              ),
              // 上一首
              _buildControlBtn(
                icon: Icons.skip_previous_rounded,
                size: 32,
                onTap: () => globalPlayer.playPrevious(),
              ),
              // 播放/暂停 — 主按钮
              GestureDetector(
                onTap: () => globalPlayer.togglePlay(),
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
                      globalPlayerStore.isPlay ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      key: ValueKey(globalPlayerStore.isPlay),
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
                onTap: () => globalPlayer.playNext(),
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
          // 底部操作栏（播放模式/倍速/收藏/下载）
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(
                  _playModeIcon(globalSettingStore.playMode),
                  size: 24,
                  color: colorScheme.onSurfaceVariant,
                ),
                onPressed: () => globalPlayer.togglePlayMode(),
              ),
              IconButton(
                icon: Icon(
                  Icons.favorite_border_rounded,
                  size: 24,
                  color: colorScheme.onSurfaceVariant,
                ),
                onPressed: () => _addToFavorite(),
              ),
              _buildSpeedBtn(context),
              IconButton(
                icon: Icon(
                  Icons.download_rounded,
                  size: 24,
                  color: colorScheme.onSurfaceVariant,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('下载功能开发中'),
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
      context.read<ListStore>().addSongToList('love', globalPlayerStore.playMusicInfo!.musicInfo.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已收藏 ♡'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
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

  void _showSourceSwitcher(PlayMusicInfo info) {
    final sources = MusicSource.values.where((s) => s.id != 'local').toList();
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
              const SizedBox(height: 16),
              Text(
                '切换音源',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              ...sources.map((src) => ListTile(
                    leading: Icon(
                      Icons.music_note,
                      color: globalPlayerStore.playMusicInfo!.musicInfo.source == src
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(src.name),
                    subtitle: Text(src.id.toUpperCase()),
                    trailing: globalPlayerStore.playMusicInfo!.musicInfo.source == src
                        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      _switchSource(src, globalPlayerStore.playMusicInfo!.musicInfo.name, globalPlayerStore.playMusicInfo!.musicInfo.singer);
                    },
                  )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _switchSource(MusicSource source, String songName, String singer) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('正在搜索 ${source.name}...'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );

      final searchService = MusicSearchService(SearchStore());
      final keyword = '$songName $singer';
      final results = await searchService.search(keyword, source, 1);

      if (results.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${source.name} 未找到该歌曲'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // 找到最佳匹配（优先精确匹配歌名+歌手）
      final exactMatch = results.where((s) =>
          s.name == songName && s.singer == singer).toList();
      final song = exactMatch.isNotEmpty ? exactMatch.first : results.first;

      await globalPlayer.playMusic(song);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已切换到 ${source.name}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('换源失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildSpeedBtn(BuildContext context) {
    final store = context.watch<SettingStore>();
    final colorScheme = Theme.of(context).colorScheme;
    final speedLabel = store.speed == store.speed.roundToDouble()
        ? '${store.speed.toInt()}x'
        : '${store.speed}x';

    return InkWell(
      onTap: () => _showSpeedPicker(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 2),
            Text(
              speedLabel,
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

  void _showSpeedPicker(BuildContext context) {
    final store = context.read<SettingStore>();
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
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
              const SizedBox(height: 16),
              Text(
                '倍速播放',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: speeds.map((s) {
                    final isSelected = store.speed == s;
                    final label = s == s.roundToDouble() ? '${s.toInt()}x' : '${s}x';
                    return GestureDetector(
                      onTap: () {
                        store.setSpeed(s);
                        globalPlayer.setPlayRate(s);
                        Navigator.pop(context);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected
                              ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                              : null,
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
