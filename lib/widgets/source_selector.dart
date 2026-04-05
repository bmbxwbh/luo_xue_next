import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import '../models/enums.dart';
import '../services/settings/setting_store.dart';

/// 音源选择器 — 水平滚动的音源切换 chips（支持 MD3 / 液态玻璃）
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

  bool _isGlass(BuildContext ctx) => ctx.watch<SettingStore>().appStyle == 'liquid_glass';

  @override
  Widget build(BuildContext context) {
    final glass = _isGlass(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: _sources.map((info) {
          final selected = info.source == currentSource;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: glass
                ? _buildGlassChip(info, selected, context)
                : FilterChip(
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

  Widget _buildGlassChip(_SourceInfo info, bool selected, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onChanged(info.source),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              info.icon,
              size: 16,
              color: selected ? cs.onPrimary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              info.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
