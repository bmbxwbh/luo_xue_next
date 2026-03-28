import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/enums.dart';
import '../../models/leaderboard_info.dart';
import '../../models/song_model.dart';
import '../../services/settings/setting_store.dart';
import '../../services/player/player_service.dart';
import '../../widgets/source_selector.dart';
import '../../widgets/song_list_tile.dart';

/// 排行榜 Tab
class TabLeaderboard extends StatefulWidget {
  const TabLeaderboard({super.key});

  @override
  State<TabLeaderboard> createState() => _TabLeaderboardState();
}

class _TabLeaderboardState extends State<TabLeaderboard> {
  MusicSource _source = MusicSource.kw;
  int _selectedIndex = 0;

  // 模拟排行榜数据
  final Map<MusicSource, List<LeaderboardInfo>> _leaderboards = {
    MusicSource.kw: [
      const LeaderboardInfo(id: 'kw_1', name: '飙升榜', bangid: '93', source: 'kw'),
      const LeaderboardInfo(id: 'kw_2', name: '新歌榜', bangid: '17', source: 'kw'),
      const LeaderboardInfo(id: 'kw_3', name: '热歌榜', bangid: '18', source: 'kw'),
      const LeaderboardInfo(id: 'kw_4', name: '说唱榜', bangid: '24', source: 'kw'),
      const LeaderboardInfo(id: 'kw_5', name: '古典榜', bangid: '26', source: 'kw'),
      const LeaderboardInfo(id: 'kw_6', name: '电音榜', bangid: '25', source: 'kw'),
      const LeaderboardInfo(id: 'kw_7', name: 'ACG榜', bangid: '27', source: 'kw'),
      const LeaderboardInfo(id: 'kw_8', name: '原创榜', bangid: '22', source: 'kw'),
    ],
    MusicSource.kg: [
      const LeaderboardInfo(id: 'kg_1', name: '飙升榜', bangid: '6666', source: 'kg'),
      const LeaderboardInfo(id: 'kg_2', name: '新歌榜', bangid: '8888', source: 'kg'),
      const LeaderboardInfo(id: 'kg_3', name: '热歌榜', bangid: '1111', source: 'kg'),
    ],
    MusicSource.tx: [
      const LeaderboardInfo(id: 'tx_1', name: '飙升榜', bangid: '62', source: 'tx'),
      const LeaderboardInfo(id: 'tx_2', name: '新歌榜', bangid: '27', source: 'tx'),
      const LeaderboardInfo(id: 'tx_3', name: '热歌榜', bangid: '26', source: 'tx'),
    ],
    MusicSource.wy: [
      const LeaderboardInfo(id: 'wy_1', name: '飙升榜', bangid: '19723756', source: 'wy'),
      const LeaderboardInfo(id: 'wy_2', name: '新歌榜', bangid: '3779629', source: 'wy'),
      const LeaderboardInfo(id: 'wy_3', name: '热歌榜', bangid: '3778678', source: 'wy'),
    ],
    MusicSource.mg: [
      const LeaderboardInfo(id: 'mg_1', name: '飙升榜', bangid: '1', source: 'mg'),
      const LeaderboardInfo(id: 'mg_2', name: '新歌榜', bangid: '2', source: 'mg'),
      const LeaderboardInfo(id: 'mg_3', name: '热歌榜', bangid: '3', source: 'mg'),
    ],
  };

  // 模拟歌曲数据
  List<SongModel> _songs = [];

  @override
  void initState() {
    super.initState();
    final setting = context.read<SettingStore>();
    _source = setting.defaultSource;
    _loadSongs();
  }

  void _loadSongs() {
    // 模拟排行榜歌曲
    _songs = List.generate(
      30,
      (i) => SongModel(
        id: '${_source.id}_lb_$i',
        name: '排行榜歌曲 ${i + 1}',
        singer: '歌手 ${i + 1}',
        source: _source,
        interval: '${2 + (i % 3)}:${(i * 7 % 60).toString().padLeft(2, '0')}',
        intervalSec: 120 + i * 7,
        meta: MusicInfoMeta(
          songId: 'lb_$i',
          albumName: '专辑 ${i + 1}',
          picUrl: '',
          qualitys: const [MusicType(type: '320k')],
          qualitysMap: const {'320k': MusicType(type: '320k')},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boards = _leaderboards[_source] ?? [];

    return Column(
      children: [
        SourceSelector(
          currentSource: _source,
          onChanged: (src) {
            setState(() {
              _source = src;
              _selectedIndex = 0;
              _loadSongs();
            });
          },
        ),
        Expanded(
          child: Row(
            children: [
              // 左侧榜单列表
              SizedBox(
                width: 120,
                child: _buildBoardList(boards),
              ),
              const VerticalDivider(width: 1),
              // 右侧歌曲列表
              Expanded(child: _buildSongList()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBoardList(List<LeaderboardInfo> boards) {
    return ListView.builder(
      itemCount: boards.length,
      itemBuilder: (context, index) {
        final board = boards[index];
        final selected = index == _selectedIndex;
        return ListTile(
          title: Text(
            board.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          selected: selected,
          onTap: () {
            setState(() {
              _selectedIndex = index;
              _loadSongs();
            });
          },
        );
      },
    );
  }

  Widget _buildSongList() {
    if (_songs.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    return ListView.builder(
      itemCount: _songs.length,
      itemBuilder: (context, index) {
        final song = _songs[index];
        return SongListTile(
          song: song,
          index: index,
          listId: 'leaderboard',
        );
      },
    );
  }
}
