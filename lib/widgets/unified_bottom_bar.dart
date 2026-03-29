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

  /// 有播放器时的布局：左侧歌曲信息 + 中间导航 + 右侧控制
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
          // 左侧：封面 + 歌曲信息
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  _buildCover(info.displayImg),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.statusText.isNotEmpty
                              ? store.statusText
                              : FormatUtil.decodeName(info.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: store.statusText.isNotEmpty
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          FormatUtil.formatSingerName(info.singer),
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
                ],
              ),
            ),
          ),
          // 中间：导航图标
          _buildNavIcons(theme, compact: true),
          // 右侧：播放控制
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    store.isPlay ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 28,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: () => globalPlayer.togglePlay(),
                  splashRadius: 20,
                ),
                IconButton(
                  icon: Icon(
                    Icons.skip_next_rounded,
                    size: 24,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => globalPlayer.playNext(),
                  splashRadius: 20,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 无播放器时的布局：纯导航
  Widget _buildNavOnly(ThemeData theme) {
    return _buildNavIcons(theme, compact: false);
  }

  /// 导航图标
  Widget _buildNavIcons(ThemeData theme, {required bool compact}) {
    final icons = [
      Icons.home_outlined,
      Icons.search_outlined,
      Icons.library_music_outlined,
      Icons.settings_outlined,
    ];
    final selectedIcons = [
      Icons.home_rounded,
      Icons.search_rounded,
      Icons.library_music_rounded,
      Icons.settings_rounded,
    ];
    final labels = ['首页', '搜索', '我的', '设置'];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final selected = currentIndex == i;
        return GestureDetector(
          onTap: () => onTap(i),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 16,
              vertical: compact ? 4 : 6,
            ),
            decoration: selected
                ? BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withAlpha(180),
                    borderRadius: BorderRadius.circular(14),
                  )
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    selected ? selectedIcons[i] : icons[i],
                    key: ValueKey('${i}_${selected}'),
                    size: compact ? 18 : 22,
                    color: selected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    child: Text(labels[i]),
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }

  /// 封面
  Widget _buildCover(String? url) {
    return Hero(
      tag: url != null && url.isNotEmpty ? 'mini_cover_$url' : 'mini_cover_empty',
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey.shade300,
        ),
        child: url != null && url.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  url,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  cacheWidth: 80,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.music_note, size: 22),
                ),
              )
            : const Icon(Icons.music_note, size: 22),
      ),
    );
  }
}
