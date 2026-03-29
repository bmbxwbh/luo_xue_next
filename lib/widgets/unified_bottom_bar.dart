import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../store/player_store.dart';
import '../utils/format_util.dart';
import '../screens/play_detail/play_detail_screen.dart';
import '../utils/global.dart';
import '../utils/page_transitions.dart';

/// 统一毛玻璃底栏 — 集成导航 + 迷你播放器 + 进度条
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
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final hasPlayer = playMusicInfo != null;
    final barHeight = hasPlayer ? 108.0 : 64.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      height: barHeight + bottomPad,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条（有歌曲时显示，与底栏融合）
          if (hasPlayer) _buildProgress(store, context),
          // 主底栏
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh.withAlpha(150),
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.outlineVariant.withAlpha(40),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomPad),
                    child: hasPlayer
                        ? _buildWithPlayer(store, playMusicInfo, theme, context)
                        : _buildNavOnly(theme),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 进度条 — 融合在底栏顶部
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
        child: Stack(
          children: [
            // 背景
            Container(
              height: 3,
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
            ),
            // 进度
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

  /// 有播放器时的布局：导航在两侧，封面+控制居中
  Widget _buildWithPlayer(PlayerStore store, playMusicInfo, ThemeData theme, BuildContext context) {
    final info = playMusicInfo.musicInfo;

    return GestureDetector(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          SlideUpRoute(page: const PlayDetailScreen()),
        );
      },
      child: Row(
        children: [
          // 左侧导航
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSingleNav(theme, 0, Icons.home_outlined, Icons.home_rounded),
                _buildSingleNav(theme, 1, Icons.search_outlined, Icons.search_rounded),
              ],
            ),
          ),
          // 中间：上一首 + 封面（叠播放/暂停）+ 下一首
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 上一首
              IconButton(
                icon: Icon(
                  Icons.skip_previous_rounded,
                  size: 22,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: () => globalPlayer.playPrevious(),
                splashRadius: 18,
              ),
              const SizedBox(width: 2),
              // 封面 + 播放/暂停叠在上面
              GestureDetector(
                onTap: () => globalPlayer.togglePlay(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildCover(info.displayImg, size: 44),
                    // 半透明遮罩 + 播放图标
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.black.withAlpha(store.isPlay ? 0 : 60),
                      ),
                      child: AnimatedOpacity(
                        opacity: store.isPlay ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 26,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              // 下一首
              IconButton(
                icon: Icon(
                  Icons.skip_next_rounded,
                  size: 22,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: () => globalPlayer.playNext(),
                splashRadius: 18,
              ),
            ],
          ),
          // 右侧导航
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSingleNav(theme, 2, Icons.library_music_outlined, Icons.library_music_rounded),
                _buildSingleNav(theme, 3, Icons.settings_outlined, Icons.settings_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 无播放器时的布局：导航居中
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

  /// 封面
  Widget _buildCover(String? url, {double size = 40}) {
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
                      const Icon(Icons.music_note, size: 22),
                ),
              )
            : const Icon(Icons.music_note, size: 22),
      ),
    );
  }
}
