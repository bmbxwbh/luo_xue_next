import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                        ? _buildWithPlayer(store, playMusicInfo, theme, context)
                        : _buildNavOnly(theme),
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

  /// 有播放器：导航两侧滑开，封面+控制居中浮现
  Widget _buildWithPlayer(PlayerStore store, playMusicInfo, ThemeData theme, BuildContext context) {
    final info = playMusicInfo.musicInfo;
    final isPlaying = store.isPlay;

    return Stack(
      children: [
        // 左侧导航 — 播放时向左滑出
        AnimatedPositioned(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          left: isPlaying ? 4 : 0,
          right: isPlaying ? 0 : 0, // 由 Row 控制
          top: 0,
          bottom: 0,
          width: isPlaying ? 60 : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isPlaying ? 0.6 : 1.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSingleNav(theme, 0, Icons.home_outlined, Icons.home_rounded),
                _buildSingleNav(theme, 1, Icons.search_outlined, Icons.search_rounded),
              ],
            ),
          ),
        ),

        // 右侧导航 — 播放时向右滑出
        AnimatedPositioned(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          right: isPlaying ? 4 : 0,
          left: isPlaying ? 0 : 0,
          top: 0,
          bottom: 0,
          width: isPlaying ? 60 : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isPlaying ? 0.6 : 1.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSingleNav(theme, 2, Icons.library_music_outlined, Icons.library_music_rounded),
                _buildSingleNav(theme, 3, Icons.settings_outlined, Icons.settings_rounded),
              ],
            ),
          ),
        ),

        // 中间：音乐控件 — 播放时浮现放大
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            height: 56,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 上一首
                AnimatedSlide(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  offset: isPlaying ? Offset.zero : const Offset(0.3, 0),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: isPlaying ? 1.0 : 0.3,
                    child: IconButton(
                      icon: Icon(Icons.skip_previous_rounded, size: 22, color: theme.colorScheme.onSurfaceVariant),
                      onPressed: () => globalPlayer.playPrevious(),
                      splashRadius: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                // 封面：单击播放/暂停，长按进详情
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  width: isPlaying ? 48 : 44,
                  height: isPlaying ? 48 : 44,
                  child: GestureDetector(
                    onTap: () => globalPlayer.togglePlay(),
                    onLongPress: () {
                      Navigator.of(context, rootNavigator: true).push(
                        SlideUpRoute(page: const PlayDetailScreen()),
                      );
                    },
                    child: _AnimatedCover(
                      url: info.displayImg,
                      isPlaying: isPlaying,
                      size: isPlaying ? 48 : 44,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                // 下一首
                AnimatedSlide(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  offset: isPlaying ? Offset.zero : const Offset(-0.3, 0),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: isPlaying ? 1.0 : 0.3,
                    child: IconButton(
                      icon: Icon(Icons.skip_next_rounded, size: 22, color: theme.colorScheme.onSurfaceVariant),
                      onPressed: () => globalPlayer.playNext(),
                      splashRadius: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 无播放器：导航居中
  Widget _buildNavOnly(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSingleNav(theme, 0, Icons.home_outlined, Icons.home_rounded),
        _buildSingleNav(theme, 1, Icons.search_outlined, Icons.search_rounded),
        _buildSingleNav(theme, 2, Icons.library_music_outlined, Icons.library_music_rounded),
        _buildSingleNav(theme, 3, Icons.settings_outlined, Icons.settings_rounded),
      ],
    );
  }

  /// 单个导航图标
  Widget _buildSingleNav(ThemeData theme, int index, IconData icon, IconData selectedIcon) {
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildCover(widget.url, widget.size),
          // 暂停图标
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.size * 0.25),
              color: Colors.black.withAlpha(widget.isPlaying ? 0 : 60),
            ),
            child: AnimatedOpacity(
              opacity: widget.isPlaying ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.play_arrow_rounded, size: widget.size * 0.55, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCover(String? url, double size) {
    return Hero(
      tag: url != null && url.isNotEmpty ? 'mini_cover_$url' : 'mini_cover_empty',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.25),
          color: Colors.grey.shade300,
        ),
        child: url != null && url.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(size * 0.25),
                child: Image.network(
                  url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  cacheWidth: (size * 2).round(),
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.music_note, size: size * 0.5),
                ),
              )
            : Icon(Icons.music_note, size: size * 0.5),
      ),
    );
  }
}
