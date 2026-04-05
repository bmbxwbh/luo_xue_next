import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/playlist_info.dart';
import '../../models/song_model.dart';
import '../../models/enums.dart';
import '../../services/player/player_service.dart';
import '../../widgets/song_list_tile.dart';
import '../../utils/format_util.dart';
import '../../music_sdk/kw/song_list.dart';

import '../../music_sdk/wy/song_list.dart';
import '../../music_sdk/tx/song_list.dart';
import '../../music_sdk/mg/song_list.dart';

/// 歌单详情页
class SonglistDetailScreen extends StatefulWidget {
  final PlaylistInfo playlist;

  const SonglistDetailScreen({super.key, required this.playlist});

  @override
  State<SonglistDetailScreen> createState() => _SonglistDetailScreenState();
}

class _SonglistDetailScreenState extends State<SonglistDetailScreen> {
  List<SongModel> _songs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      Map<String, dynamic> result;
      final source = MusicSource.fromId(widget.playlist.source);
      final playlistId = widget.playlist.id;

      switch (source) {
        case MusicSource.kw:
          result = await KwSongList.getListDetail(playlistId, 1);
          break;
        case MusicSource.kg:
          // 酷狗歌单详情需解析HTML页面，暂不支持直接获取
          throw Exception('酷狗歌单详情暂不支持，请在其他音源查看');
        case MusicSource.wy:
          result = await WySongList.getListDetail(playlistId);
          break;
        case MusicSource.tx:
          result = await TxSongList.getListDetail(playlistId);
          break;
        case MusicSource.local:
          result = {'list': [], 'hasMore': false};
          break;
        case MusicSource.mg:
          result = await MgSongList.getListDetail(playlistId);
          break;
      }

      final rawList = result['list'] as List? ?? [];
      final songs = rawList.map<SongModel>((item) {
        if (item is Map<String, dynamic>) {
          return SongModel.fromLxJson(item, source);
        }
        return SongModel.fromLxJson(item as Map<String, dynamic>, source);
      }).toList();

      if (mounted) {
        setState(() {
          _songs = songs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '加载歌曲失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 头部
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.playlist.name,
                style: const TextStyle(
                  shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                ),
              ),
              background: Hero(
                tag: 'playlist_${widget.playlist.id}',
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.playlist.img.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.playlist.img,
                            fit: BoxFit.cover,
                            memCacheWidth: 600,
                            errorWidget: (_, __, ___) => _buildPlaceholder(context),
                          )
                        : _buildPlaceholder(context),
                    // 渐变遮罩
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black54],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 描述
          SliverToBoxAdapter(child: _buildInfo(context)),
          // 操作按钮
          if (!_isLoading && _error == null)
            SliverToBoxAdapter(child: _buildActionButtons(context)),
          // 内容区域
          _buildContent(),
          // 底部安全区
          const SliverPadding(padding: EdgeInsets.only(bottom: 60)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loadSongs,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    if (_songs.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('暂无歌曲')),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => SongListTile(
          song: _songs[index],
          index: index,
          listId: 'playlist_${widget.playlist.id}',
        ),
        childCount: _songs.length,
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: const Center(
        child: Icon(Icons.music_note, size: 80, color: Colors.white38),
      ),
    );
  }

  Widget _buildInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.person, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.playlist.author,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${FormatUtil.formatNumber(int.tryParse(widget.playlist.playCount) ?? 0)} 次播放',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (widget.playlist.desc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.playlist.desc,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _isLoading ? '加载中...' : '共 ${_songs.length} 首歌曲',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('播放全部'),
              onPressed: _songs.isEmpty
                  ? null
                  : () {
                      final player = context.read<PlayerService>();
                      player.playSong(_songs.first, listId: 'playlist_${widget.playlist.id}');
                    },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.shuffle),
              label: const Text('随机播放'),
              onPressed: _songs.isEmpty
                  ? null
                  : () {
                      final player = context.read<PlayerService>();
                      final shuffled = List<SongModel>.from(_songs)..shuffle();
                      player.playSong(shuffled.first, listId: 'playlist_${widget.playlist.id}');
                    },
            ),
          ),
        ],
      ),
    );
  }
}
