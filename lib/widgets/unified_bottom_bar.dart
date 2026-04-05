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

class UnifiedBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const UnifiedBottomBar({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlayerStore>();
    final appStyle = context.watch<SettingStore>().appStyle;
    final isGlass = appStyle == 'liquid_glass';
    final playMusicInfo = store.playMusicInfo;
    final theme = Theme.of(context);
    final hasPlayer = playMusicInfo != null;
    final barHeight = hasPlayer ? 130.0 : 70.0;

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
            if (hasPlayer) _buildGlassProgress(store, context),
            Expanded(
              child: isGlass
                  ? GlassCard(
                      child: hasPlayer
                          ? _buildGlassPlayerBar(store, playMusicInfo, theme, context, isGlass)
                          : _buildNavBar(theme, isGlass),
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
                              ? _buildPlayerBar(store, playMusicInfo, theme, context, isGlass)
                              : _buildNavBar(theme, isGlass),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassProgress(PlayerStore store, BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        final ratio = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
        final maxMs = store.progress.maxPlayTime;
        if (maxMs > 0) {
          globalPlayer.seekTo(Duration(milliseconds: (maxMs * ratio).round()));
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

  Widget _buildGlassPlayerBar(
    PlayerStore store,
    dynamic playMusicInfo,
    ThemeData theme,
    BuildContext context,
    bool isGlass,
  ) {
    final info = playMusicInfo.musicInfo;
    return Row(
      children: [
        const SizedBox(width: 6),
        _buildCompactNav(theme, 0, Icons.home_outlined, Icons.home_rounded),
        _buildCompactNav(theme, 1, Icons.search_outlined, Icons.search_rounded),
        const Spacer(),
        _GlassButton(
          child: Icon(Icons.skip_previous_rounded, size: 22, color: theme.colorScheme.onSurfaceVariant),
          onPressed: () => globalPlayer.playPrevious(),
          isGlass: isGlass,
        ),
        const SizedBox(width: 4),
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

  Widget _buildProgress(PlayerStore store, BuildContext context) {
    final progress = store.progress.progress.clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        final ratio = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
        final maxMs = store.progress.maxPlayTime;
        if (maxMs > 0) {
          globalPlayer.seekTo(Duration(milliseconds: (maxMs * ratio).round()));
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

  Widget _buildPlayerBar(
    PlayerStore store,
    dynamic playMusicInfo,
    ThemeData theme,
    BuildContext context,
    bool isGlass,
  ) {
    final info = playMusicInfo.musicInfo;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildProgress(store, context),
        Row(
          children: [
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                Navigator.of(context, rootNavigator: true).push(
                  SlideUpRoute(page: const PlayDetailScreen()),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: info.displayImg,
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 42,
                    height: 42,
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 42,
                    height: 42,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.music_note, color: theme.colorScheme.onSurfaceVariant, size: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    info.songName ?? '未知歌曲',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600) ??
                        const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    info.singer ?? '未知歌手',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ) ?? const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: IconButton(
                icon: Icon(store.isPlay ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 20),
                onPressed: () => globalPlayer.togglePlay(),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 64, right: 12),
          child: Row(
            children: [
              _buildMiniNav(theme, 0, Icons.home_outlined, Icons.home_rounded),
              _buildMiniNav(theme, 1, Icons.search_outlined, Icons.search_rounded),
              const Spacer(),
              _buildMiniNav(theme, 2, Icons.library_music_outlined, Icons.library_music_rounded),
              _buildMiniNav(theme, 3, Icons.settings_outlined, Icons.settings_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavBar(ThemeData theme, bool isGlass) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(theme, 0, Icons.home_outlined, Icons.home_rounded, isGlass),
          _buildNavItem(theme, 1, Icons.search_outlined, Icons.search_rounded, isGlass),
          _buildNavItem(theme, 2, Icons.library_music_outlined, Icons.library_music_rounded, isGlass),
          _buildNavItem(theme, 3, Icons.settings_outlined, Icons.settings_rounded, isGlass),
        ],
      ),
    );
  }

  Widget _buildNavItem(ThemeData theme, int index, IconData icon, IconData activeIcon, bool isGlass) {
    final selected = currentIndex == index;
    final color = selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    return IconButton(
      isSelected: selected,
      icon: Icon(icon, size: 22),
      selectedIcon: Icon(activeIcon, size: 22),
      onPressed: () => onTap(index),
      color: color,
      style: IconButton.styleFrom(
        backgroundColor: isGlass && selected ? theme.colorScheme.primary.withAlpha(30) : null,
      ),
    );
  }

  Widget _buildCompactNav(ThemeData theme, int index, IconData icon, IconData activeIcon) {
    final selected = currentIndex == index;
    return IconButton(
      isSelected: selected,
      icon: Icon(icon, size: 22),
      selectedIcon: Icon(activeIcon, size: 22),
      onPressed: () => onTap(index),
      color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
      style: IconButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _buildMiniNav(ThemeData theme, int index, IconData icon, IconData activeIcon) {
    final selected = currentIndex == index;
    return IconButton(
      isSelected: selected,
      icon: Icon(icon, size: 20),
      selectedIcon: Icon(activeIcon, size: 20),
      onPressed: () => onTap(index),
      color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
      style: IconButton.styleFrom(padding: const EdgeInsets.all(6)),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  final bool isGlass;

  const _GlassButton({required this.child, required this.onPressed, required this.isGlass});

  @override
  Widget build(BuildContext context) {
    if (isGlass) {
      return InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: child,
        ),
      );
    }
    return IconButton(onPressed: onPressed, icon: child, padding: const EdgeInsets.all(8));
  }
}

class _GlassCoverCard extends StatelessWidget {
  final Widget child;
  const _GlassCoverCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withAlpha(80),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

class _AnimatedCover extends StatefulWidget {
  final String url;
  final bool isPlaying;
  final double size;
  const _AnimatedCover({required this.url, required this.isPlaying, required this.size});

  @override
  State<_AnimatedCover> createState() => _AnimatedCoverState();
}

class _AnimatedCoverState extends State<_AnimatedCover> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
  }

  @override
  void didUpdateWidget(_AnimatedCover old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.size * 0.25),
        child: CachedNetworkImage(
          imageUrl: widget.url,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: widget.size,
            height: widget.size,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          errorWidget: (_, __, ___) => Container(
            width: widget.size,
            height: widget.size,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(Icons.music_note, color: Theme.of(context).colorScheme.onSurfaceVariant, size: widget.size * 0.5),
          ),
        ),
      ),
    );
  }
}
