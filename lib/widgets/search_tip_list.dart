import 'package:flutter/material.dart';

/// 搜索提示列表 — 输入时显示搜索建议
class SearchTipList extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onSelected;
  final VoidCallback? onClear;

  const SearchTipList({
    super.key,
    required this.suggestions,
    required this.onSelected,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onClear != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('清除'),
              ),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final tip = suggestions[index];
                return ListTile(
                  leading: const Icon(Icons.search, size: 20),
                  title: Text(tip),
                  dense: true,
                  onTap: () => onSelected(tip),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
