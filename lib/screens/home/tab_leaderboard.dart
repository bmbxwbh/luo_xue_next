import 'package:flutter/material.dart';
import '../../models/enums.dart';
import '../../models/song_model.dart';
import '../../models/leaderboard_info.dart';
import '../../services/player/player_service.dart';
import '../../music_sdk/index.dart';
import '../../music_sdk/wy/index.dart';
import '../../music_sdk/kw/index.dart';
import '../../music_sdk/kg/index.dart';
import '../../music_sdk/tx/index.dart';
import '../../music_sdk/mg/index.dart';
import '../../widgets/song_list_tile.dart';

/// 排行榜 Tab — 真实数据版
class TabLeaderboard extends StatefulWidget {
  final MusicSource source;
  const TabLeaderboard({super.key, required this.source});

  @override
  State<TabLeaderboard> createState() => _TabLeaderboardState();
}

class _TabLeaderboardState extends State<TabLeaderboard> {
  MusicSource _source = MusicSource.wy;
  int _selectedIndex = 0;
  List<LeaderboardInfo> _boards = [];
  List<SongModel> _songs = [];
  bool _loadingBoards = true;
  bool _loadingSongs = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _source = widget.source;
    _loadBoards();
  }

  @override
  void didUpdateWidget(TabLeaderboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _source = widget.source;
      _loadBoards();
    }
  }

  void _loadBoards() {
    setState(() {
      _loadingBoards = true;
      _error = null;
    });

    try {
      late List<LeaderboardInfo> boards;
      switch (_source) {
        case MusicSource.kw:
          boards = KwLeaderboard.boardList;
          break;
        case MusicSource.kg:
          boards = KgLeaderboard.boardList;
          break;
        case MusicSource.wy:
          boards = WyLeaderboard.boardList
              .map((e) => LeaderboardInfo(
                    id: e['id'],
                    name: e['name'],
                    bangid: e['bangid'],
                    source: 'wy',
                  ))
              .toList();
          break;
        case MusicSource.tx:
          boards = TxLeaderboard.boardList
              .map((e) => LeaderboardInfo(
                    id: e['id'],
                    name: e['name'],
                    bangid: '${e['bangid']}',
                    source: 'tx',
                  ))
              .toList();
          break;
        case MusicSource.mg:
          boards = MgLeaderboard.boardList
              .map((e) => LeaderboardInfo(
                    id: e['id'],
                    name: e['name'],
                    bangid: e['bangid'],
                    source: 'mg',
                  ))
              .toList();
          break;
        default:
          boards = [];
      }
      setState(() {
        _boards = boards;
        _loadingBoards = false;
        _selectedIndex = 0;
        _songs = [];
      });
      if (boards.isNotEmpty) _loadSongs();
    } catch (e) {
      setState(() {
        _loadingBoards = false;
        _error = '加载榜单失败: $e';
      });
    }
  }

  Future<void> _loadSongs() async {
    if (_boards.isEmpty) return;
    setState(() {
      _loadingSongs = true;
      _error = null;
    });

    try {
      final board = _boards[_selectedIndex];
      late Map<String, dynamic> result;

      switch (_source) {
        case MusicSource.wy:
          result = await WySdk.getLeaderboardList(board.bangid, 1);
          break;
        case MusicSource.kw:
          result = await KwSdk.getLeaderboardList(board.bangid, 1);
          break;
        case MusicSource.kg:
          result = await KgSdk.getLeaderboardList(board.bangid, 1);
          break;
        case MusicSource.tx:
          result = await TxSdk.getLeaderboardList(board.bangid, 1);
          break;
        case MusicSource.mg:
          result = await MgSdk.getLeaderboardList(board.bangid, 1);
          break;
        default:
          result = {'list': []};
      }

      final list = (result['list'] as List?) ?? [];
      setState(() {
        _songs = list
            .map((item) => SongModel.fromLxMusicInfo(item as Map<String, dynamic>))
            .toList();
        _loadingSongs = false;
      });
    } catch (e) {
      setState(() {
        _loadingSongs = false;
        _error = '加载歌曲失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_source == MusicSource.local) {
      return const Center(child: Text('本地音乐不支持排行榜'));
    }

    if (_loadingBoards) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      children: [
        // 左侧榜单列表
        SizedBox(
          width: 110,
          child: _buildBoardList(),
        ),
        VerticalDivider(width: 1, color: colorScheme.outlineVariant),
        // 右侧歌曲列表
        Expanded(child: _buildSongList()),
      ],
    );
  }

  Widget _buildBoardList() {
    return ListView.builder(
      itemCount: _boards.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) {
        final board = _boards[index];
        final selected = index == _selectedIndex;
        return InkWell(
          onTap: () {
            setState(() => _selectedIndex = index);
            _loadSongs();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              border: selected
                  ? Border(
                      left: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      ),
                    )
                  : null,
            ),
            child: Text(
              board.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSongList() {
    if (_loadingSongs) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadSongs,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_songs.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    return ListView.builder(
      itemCount: _songs.length,
      itemBuilder: (context, index) {
        return SongListTile(
          song: _songs[index],
          index: index,
          listId: 'leaderboard',
        );
      },
    );
  }
}
