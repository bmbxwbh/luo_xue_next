import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../store/player_store.dart';
import '../screens/play_detail/play_detail_screen.dart';
import '../utils/global.dart';
import '../utils/page_transitions.dart';

/// 统一毛玻璃悬浮底栏 — 集成导航 + 迷你播放器 + 进度条
class UnifiedBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const UnifiedBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlayerStore>();
    final playMusicInfo = store.playMusicInfo;
    final theme = Theme.of(context);
    final hasPlayer = playMusicInfo != null;
    final barHeight = hasPlayer ? 100.0 : 56.0;

    return SafeArea(
      top: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        height: barHeight,
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            if (hasPlayer) _buildProgress(store, context),
            // 悬浮底栏
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh.withAlpha(150),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withAlpha(60),
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(25),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 40,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: hasPlayer
                        ? _buildPlayerBar(store, playMusicInfo, theme, context)
                        : _buildNavBar(theme),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 进度条
  Widget _buildProgress(PlayerStore store, BuildContext context) {
    final progress = store.progress.progress.clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        final ratio = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
        final maxMs = store.progress.maxPlayTime;
        if (maxMs > 0) {
          globalPlayer.seekTo(Duration(milliseconds: (maxMs * ratio * 1000).round()));
        }
      },
      child: Container(
        height: 20,
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Stack(
          children: [
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withAlpha(180),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 有歌曲时的底栏 — 封面 + 歌名 + 控件 + 完整导航
  Widget _buildPlayerBar(PlayerStore store, playMusicInfo, ThemeData theme, BuildContext context) {
    final info = playMusicInfo.musicInfo;

    return Row(
      children: [
        // 封面：单击播放/暂停，长按进详情
        GestureDetector(
          onTap: () => globalPlayer.togglePlay(),
          onLongPress: () {
            Navigator.of(context, rootNavigator: true).push(
              SlideUpRoute(page: const PlayDetailScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _AnimatedCover(
              url: info.displayImg,
              isPlaying: store.isPlay,
              size: 40,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // 歌名 + 歌手
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                store.statusText.isNotEmpty
                    ? store.statusText
                    : (info.name.isNotEmpty ? info.name : '未知歌曲'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: store.statusText.isNotEmpty ? theme.colorScheme.error : null,
                ),
              ),
              if (info.singer.isNotEmpty)
                Text(
                  info.singer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        // 播放控件
        IconButton(
          icon: Icon(Icons.skip_previous_rounded, size: 22, color: theme.colorScheme.onSurfaceVariant),
          onPressed: () => globalPlayer.playPrevious(),
          splashRadius: 18,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: EdgeInsets.zero,
        ),
        IconButton(
          icon: Icon(
            store.isPlay ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
            size: 32,
            color: theme.colorScheme.primary,
          ),
          onPressed: () => globalPlayer.togglePlay(),
          splashRadius: 20,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          padding: EdgeInsets.zero,
        ),
        IconButton(
          icon: Icon(Icons.skip_next_rounded, size: 22, color: theme.colorScheme.onSurfaceVariant),
          onPressed: () => globalPlayer.playNext(),
          splashRadius: 18,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: EdgeInsets.zero,
        ),
        // 全部 4 个导航图标
        _buildCompactNav(theme, 0, Icons.home_outlined, Icons.home_rounded),
        _buildCompactNav(theme, 1, Icons.search_outlined, Icons.search_rounded),
        _buildCompactNav(theme, 2, Icons.library_music_outlined, Icons.library_music_rounded),
        _buildCompactNav(theme, 3, Icons.settings_outlined, Icons.settings_rounded),
        const SizedBox(width: 4),
      ],
    );
  }

  /// 无歌曲时的底栏 — 纯导航
  Widget _buildNavBar(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildNavIcon(theme, 0, Icons.home_outlined, Icons.home_rounded),
        _buildNavIcon(theme, 1, Icons.search_outlined, Icons.search_rounded),
        _buildNavIcon(theme, 2, Icons.library_music_outlined, Icons.library_music_rounded),
        _buildNavIcon(theme, 3, Icons.settings_outlined, Icons.settings_rounded),
      ],
    );
  }

  /// 标准导航图标（无歌曲时用）
  Widget _buildNavIcon(ThemeData theme, int index, IconData icon, IconData selectedIcon) {
    final selected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: selected
            ? BoxDecoration(
                color: theme.colorScheme.primaryContainer.withAlpha(180),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            selected ? selectedIcon : icon,
            key: ValueKey('${index}_$selected'),
            size: 20,
            color: selected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// 紧凑导航图标（有歌曲时用，小号）
  Widget _buildCompactNav(ThemeData theme, int index, IconData icon, IconData selectedIcon) {
    final selected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(
          selected ? selectedIcon : icon,
          size: 18,
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant.withAlpha(150),
        ),
      ),
    );
  }
}

/// 带动画的封面组件 — 切歌时播放缩放+淡入动画
class _AnimatedCover extends StatefulWidget {
  final String? url;
  final bool isPlaying;
  final double size;

  const _AnimatedCover({
    required this.url,
    required this.isPlaying,
    required this.size,
  });

  @override
  State<_AnimatedCover> createState() => _AnimatedCoverState();
}

class _AnimatedCoverState extends State<_AnimatedCover> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(_AnimatedCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != _currentUrl) {
      _currentUrl = widget.url;
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: Opacity(
            opacity: _fadeAnim.value,
            child: child,
          ),
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.size * 0.25),
          color: Colors.grey.shade300,
        ),
        child: widget.url != null && widget.url!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(widget.size * 0.25),
                child: CachedNetworkImage(
                  imageUrl: widget.url!,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                  memCacheWidth: (widget.size * 2).round(),
                  errorWidget: (_, __, ___) =>
                      Icon(Icons.music_note, size: widget.size * 0.5),
                ),
              )
            : Icon(Icons.music_note, size: widget.size * 0.5),
      ),
    );
  }
}
