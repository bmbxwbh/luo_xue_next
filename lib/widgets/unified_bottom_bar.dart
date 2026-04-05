import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../store/player_store.dart';
import '../screens/play_detail/play_detail_screen.dart';
import '../services/settings/setting_store.dart';
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
    final appStyle = context.watch<SettingStore>().appStyle;
    final isGlass = appStyle == 'liquid_glass';
    final playMusicInfo = store.playMusicInfo;
    final theme = Theme.of(context);
    final hasPlayer = playMusicInfo != null;
    final barHeight = hasPlayer ? 100.0 : 56.0;

    if (isGlass) {
      return _buildGlassBar(context, store, playMusicInfo, theme, hasPlayer, barHeight);
    }

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

  /// 液态玻璃风格底栏
  Widget _buildGlassBar(
    BuildContext context,
    PlayerStore store,
    dynamic playMusicInfo,
    ThemeData theme,
    bool hasPlayer,
    double barHeight,
  ) {
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
            // 进度条 — 液态玻璃模式用 GlassSlider
            if (hasPlayer) _buildGlassProgress(store, context),
            // 悬浮底栏 — 液态玻璃模式用 GlassCard 包裹
            Expanded(
              child: isGlass
                  ? GlassCard(
                      borderRadius: 24,
                      child: hasPlayer
                          ? _buildGlassPlayerBar(store, playMusicInfo, theme, context)
                          : _buildNavBar(theme),
                    )
                  : ClipRRect(
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

  /// 玻璃进度条
  Widget _buildGlassProgress(PlayerStore store, BuildContext context) {
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
              widthFactor: store.progress.progress.clamp(0.0, 1.0),
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

  /// 玻璃风格播放器底栏
  Widget _buildGlassPlayerBar(
    PlayerStore store,
    dynamic playMusicInfo,
    ThemeData theme,
    BuildContext context,
  ) {
    final info = playMusicInfo.musicInfo;
    return Row(
      children: [
        const SizedBox(width: 6),
        _buildCompactNav(theme, 0, Icons.home_outlined, Icons.home_rounded),
        _buildCompactNav(theme, 1, Icons.search_outlined, Icons.search_rounded),
        const Spacer(),
        // 上一首
        _GlassButton(
          child: Icon(Icons.skip_previous_rounded, size: 22, color: theme.colorScheme.onSurfaceVariant),
          onPressed: () => globalPlayer.playPrevious(),
          isGlass: isGlass,
        ),
        const SizedBox(width: 4),
        // 封面 + 暂停
        GestureDetector(
          onTap: () => globalPlayer.togglePlay(),
          onLongPress: () {
            Navigator.of(context, rootNavigator: true).push(
              SlideUpRoute(page: const PlayDetailScreen()),
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              isGlass
                  ? _GlassCoverCard(
                      child: _AnimatedCover(
                        url: info.displayImg,
                        isPlaying: store.isPlay,
                        size: 36,
                      ),
                    )
                  : _AnimatedCover(
                      url: info.displayImg,
                      isPlaying: store.isPlay,
                      size: 40,
                    ),
              AnimatedOpacity(
                opacity: store.isPlay ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.black45,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, size: 26, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        // 下一首
        _GlassButton(
          child: Icon(Icons.skip_next_rounded, size: 22, color: theme.colorScheme.onSurfaceVariant),
          onPressed: () => globalPlayer.playNext(),
          isGlass: isGlass,
        ),
        const Spacer(),
        _buildCompactNav(theme, 2, Icons.library_music_outlined, Icons.library_music_rounded),
        _buildCompactNav(theme, 3, Icons.settings_outlined, Icons.settings_rounded),
        const SizedBox(width: 6),
      ],
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

  /// 有歌曲时的底栏 — 导航 | 上一首 | 封面(含暂停) | 下一首 | 导航
  Widget _buildPlayerBar(PlayerStore store, playMusicInfo, ThemeData theme, BuildContext context) {
    final info = playMusicInfo.musicInfo;

    return Row(
      children: [
        const SizedBox(width: 6),
        // 左侧导航
        _buildCompactNav(theme, 0, Icons.home_outlined, Icons.home_rounded),
        _buildCompactNav(theme, 1, Icons.search_outlined, Icons.search_rounded),
        const Spacer(),
        // 上一首
        GestureDetector(
          onTap: () => globalPlayer.playPrevious(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.skip_previous_rounded, size: 24, color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 8),
        // 封面 + 暂停覆盖 — 单击暂停/播放，长按进详情
        GestureDetector(
          onTap: () => globalPlayer.togglePlay(),
          onLongPress: () {
            Navigator.of(context, rootNavigator: true).push(
              SlideUpRoute(page: const PlayDetailScreen()),
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              _AnimatedCover(
                url: info.displayImg,
                isPlaying: store.isPlay,
                size: 40,
              ),
              // 暂停/播放覆盖层
              AnimatedOpacity(
                opacity: store.isPlay ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.black45,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, size: 26, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // 下一首
        GestureDetector(
          onTap: () => globalPlayer.playNext(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.skip_next_rounded, size: 24, color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const Spacer(),
        // 右侧导航
        _buildCompactNav(theme, 2, Icons.library_music_outlined, Icons.library_music_rounded),
        _buildCompactNav(theme, 3, Icons.settings_outlined, Icons.settings_rounded),
        const SizedBox(width: 6),
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
        padding: const EdgeInsets.symmetric(horizontal: 8),
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

/// 通用玻璃按钮 (在玻璃和非玻璃模式之间切换)
class _GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  final bool isGlass;

  const _GlassButton({
    required this.child,
    required this.onPressed,
    required this.isGlass,
  });

  @override
  Widget build(BuildContext context) {
    if (isGlass) {
      return InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(6),
          child: child,
        ),
      );
    }
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(6),
        child: child,
      ),
    );
  }
}

/// 封面玻璃卡片
class _GlassCoverCard extends StatelessWidget {
  final Widget child;
  const _GlassCoverCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withAlpha(40),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11.5),
        child: child,
      ),
    );
  }
}
