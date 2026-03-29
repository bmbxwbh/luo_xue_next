import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../store/player_store.dart';
import '../utils/format_util.dart';
import '../screens/play_detail/play_detail_screen.dart';
import '../utils/global.dart';
import '../utils/page_transitions.dart';

/// 播放条 — 固定在底栏上方，始终显示
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlayerStore>();
    final playMusicInfo = store.playMusicInfo;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: playMusicInfo != null
          ? () {
              Navigator.of(context, rootNavigator: true).push(
                SlideUpRoute(page: const PlayDetailScreen()),
              );
            }
          : null,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 56,
            color: theme.colorScheme.surfaceContainerHigh.withAlpha(230),
            child: playMusicInfo != null
                ? _buildPlayingContent(store, playMusicInfo, theme)
                : _buildEmptyContent(theme),
          ),
        ),
      ),
    );
  }

  /// 有歌曲时的内容
  Widget _buildPlayingContent(PlayerStore store, playMusicInfo, ThemeData theme) {
    final info = playMusicInfo.musicInfo;
    final progressValue = store.progress.progress;

    return Stack(
      children: [
        // 进度条
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LinearProgressIndicator(
            value: progressValue.clamp(0.0, 1.0),
            minHeight: 2,
            backgroundColor: Colors.transparent,
          ),
        ),
        // 内容
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: store.statusText.isNotEmpty
                            ? theme.colorScheme.error
                            : null,
                      ),
                    ),
                    Text(
                      FormatUtil.formatSingerName(info.singer),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  store.isPlay ? Icons.pause_circle : Icons.play_circle,
                  size: 32,
                ),
                onPressed: () => globalPlayer.togglePlay(),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, size: 28),
                onPressed: () => globalPlayer.playNext(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 没有歌曲时的占位内容
  Widget _buildEmptyContent(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _buildCover(null),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '暂无播放',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCover(String? url) {
    final tag = url != null && url.isNotEmpty ? 'mini_cover_$url' : 'mini_cover_empty';
    return Hero(
      tag: tag,
      flightShuttleBuilder: (context, animation, direction, fromContext, toContext) {
        return ScaleTransition(
          scale: animation.drive(
            Tween(begin: 1.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
          ),
          child: fromContext.widget,
        );
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Colors.grey.shade300,
        ),
        child: url != null && url.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  url,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  cacheWidth: 80,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.music_note, size: 24),
                ),
              )
            : const Icon(Icons.music_note, size: 24),
      ),
    );
  }
}
