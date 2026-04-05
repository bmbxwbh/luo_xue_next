import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/audio/equalizer_service.dart';

/// 均衡器设置页面
class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  @override
  Widget build(BuildContext context) {
    final service = context.watch<EqualizerService>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('均衡器'),
        centerTitle: true,
        actions: [
          // 启用/禁用开关
          Switch(
            value: service.isEnabled,
            onChanged: (v) => service.setEnabled(v),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: !service.initialized
          ? const Center(child: CircularProgressIndicator())
          : Opacity(
              opacity: service.isEnabled ? 1.0 : 0.5,
              child: AbsorbPointer(
                absorbing: !service.isEnabled,
                child: Column(
                  children: [
                    // 预设选择区域
                    _buildPresetSelector(context, service, colorScheme),
                    
                    const Divider(height: 1),
                    
                    // 频段滑块区域
                    Expanded(
                      child: _buildBandSliders(context, service, colorScheme),
                    ),
                    
                    // 底部操作栏
                    _buildBottomBar(context, service),
                  ],
                ),
              ),
            ),
    );
  }

  /// 预设选择器 - 横向滚动的 Chip 列表
  Widget _buildPresetSelector(
    BuildContext context,
    EqualizerService service,
    ColorScheme colorScheme,
  ) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: EqualizerService.presets.length + 1, // +1 for Custom
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          // 最后一个位置是"自定义"
          if (index == EqualizerService.presets.length) {
            final isSelected = service.isCustom;
            return FilterChip(
              label: const Text('自定义'),
              selected: isSelected,
              onSelected: (_) {
                // 自定义模式下不切换预设
              },
              avatar: isSelected ? const Icon(Icons.tune, size: 18) : null,
            );
          }

          final preset = EqualizerService.presets[index];
          final isSelected = service.currentPresetIndex == index;

          return FilterChip(
            label: Text(preset.name),
            selected: isSelected,
            onSelected: (_) => service.applyPreset(index),
            avatar: isSelected
                ? const Icon(Icons.check, size: 18)
                : null,
          );
        },
      ),
    );
  }

  /// 频段滑块区域
  Widget _buildBandSliders(
    BuildContext context,
    EqualizerService service,
    ColorScheme colorScheme,
  ) {
    final bands = service.bands;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: bands.asMap().entries.map((entry) {
          final index = entry.key;
          final band = entry.value;
          
          return Expanded(
            child: _buildSingleBandSlider(
              context: context,
              band: band,
              colorScheme: colorScheme,
              onChanged: (value) {
                service.setBandLevel(index, (value * 1000).round());
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 单个频段滑块
  Widget _buildSingleBandSlider({
    required BuildContext context,
    required EqualizerBand band,
    required ColorScheme colorScheme,
    required ValueChanged<double> onChanged,
  }) {
    // 将 mB 值转换为 -1.0 ~ 1.0 的滑块值
    final sliderValue = band.currentLevel / 1000.0;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // dB 值显示
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${band.levelInDb >= 0 ? '+' : ''}${band.levelInDb.toStringAsFixed(1)} dB',
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // 滑块 (纵向)
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 背景轨道
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 滑块
              RotatedBox(
                quarterTurns: 3, // 旋转 270 度变成纵向
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 20,
                    ),
                    activeTrackColor: colorScheme.primary,
                    inactiveTrackColor: colorScheme.surfaceContainerHighest,
                    thumbColor: colorScheme.primary,
                  ),
                  child: Slider(
                    value: sliderValue.clamp(-1.0, 1.0),
                    min: -1.0,
                    max: 1.0,
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // 频率标签
        Text(
          band.freqLabel,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 底部操作栏
  Widget _buildBottomBar(BuildContext context, EqualizerService service) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('重置均衡器'),
                      content: const Text('确定要将所有频段恢复到默认值吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () {
                            service.reset();
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('已重置'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Text('重置'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.restart_alt),
                label: const Text('重置'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
