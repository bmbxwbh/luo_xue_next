import 'package:flutter/material.dart';
import '../models/enums.dart';

/// 音源选择器 — 水平滚动的音源切换 chips
class SourceSelector extends StatelessWidget {
  final MusicSource currentSource;
  final ValueChanged<MusicSource> onChanged;
  final EdgeInsetsGeometry? padding;

  const SourceSelector({
    super.key,
    required this.currentSource,
    required this.onChanged,
    this.padding,
  });

  static const List<_SourceInfo> _sources = [
    _SourceInfo(MusicSource.kw, '酷我', Icons.music_note),
    _SourceInfo(MusicSource.kg, '酷狗', Icons.headphones),
    _SourceInfo(MusicSource.tx, 'QQ', Icons.queue_music),
    _SourceInfo(MusicSource.wy, '网易云', Icons.cloud),
    _SourceInfo(MusicSource.mg, '咪咕', Icons.radio),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: _sources.map((info) {
          final selected = info.source == currentSource;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: selected,
              label: Text(info.name),
              avatar: Icon(
                info.icon,
                size: 18,
                color: selected ? null : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onSelected: (_) => onChanged(info.source),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SourceInfo {
  final MusicSource source;
  final String name;
  final IconData icon;
  const _SourceInfo(this.source, this.name, this.icon);
}
