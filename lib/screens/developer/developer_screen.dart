import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_logger.dart';
import '../../services/log/log_upload_service.dart';

/// 开发者模式 — 错误日志查看
class DeveloperScreen extends StatefulWidget {
  const DeveloperScreen({super.key});

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  LogLevel _filter = LogLevel.error;
  bool _autoScroll = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('开发者模式'),
        actions: [
          // 过滤级别
          PopupMenuButton<LogLevel>(
            icon: const Icon(Icons.filter_list),
            onSelected: (lv) => setState(() => _filter = lv),
            itemBuilder: (_) => LogLevel.values
                .map((lv) => PopupMenuItem(
                      value: lv,
                      child: Text(switch (lv) {
                        LogLevel.debug => '全部',
                        LogLevel.info => 'INFO+',
                        LogLevel.warn => 'WARN+',
                        LogLevel.error => '仅ERROR',
                      }),
                    ))
                .toList(),
          ),
          // 导出
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: '复制日志',
            onPressed: _copyLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空',
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // 统计栏
          _buildStatsBar(),
          // 日志列表
          Expanded(child: _buildLogList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => setState(() => _autoScroll = !_autoScroll),
        backgroundColor: _autoScroll ? Colors.green : Colors.grey,
        child: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.pause),
      ),
    );
  }

  Widget _buildStatsBar() {
    final logs = logger.logs;
    final errors = logs.where((l) => l.level == LogLevel.error).length;
    final warns = logs.where((l) => l.level == LogLevel.warn).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          _statChip('总计 ${logs.length}', Colors.grey),
          const SizedBox(width: 8),
          _statChip('错误 $errors', Colors.red),
          const SizedBox(width: 8),
          _statChip('警告 $warns', Colors.orange),
          const Spacer(),
          ListenableBuilder(
            listenable: logger,
            builder: (_, __) => Switch(
              value: logger.enabled,
              onChanged: (v) => logger.setEnabled(v),
            ),
          ),
          const Text('收集', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          const Text('|', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          // 上传开关
          ListenableBuilder(
            listenable: logger,
            builder: (_, __) => Switch(
              value: LogUploadService().enabled,
              onChanged: (v) async {
                await LogUploadService().setEnabled(v);
                setState(() {});
              },
            ),
          ),
          const Text('缓存', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          // 手动上传按钮
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined, size: 20),
            tooltip: '上传日志',
            onPressed: _uploadLogs,
          ),
        ],
      ),
    );
  }

  Widget _statChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }

  Widget _buildLogList() {
    return ListenableBuilder(
      listenable: logger,
      builder: (context, _) {
        final filtered = logger.logs
            .where((l) => l.level.index >= _filter.index)
            .toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 48, color: Colors.green.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text(
                  logger.enabled ? '暂无日志' : '请先开启日志收集',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 60),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final entry = filtered[index];
            final color = switch (entry.level) {
              LogLevel.error => Colors.red,
              LogLevel.warn => Colors.orange,
              LogLevel.info => Colors.blue,
              LogLevel.debug => Colors.grey,
            };

            return InkWell(
              onTap: () => _showDetail(entry),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: color, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '[${entry.levelStr}]',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: color),
                        ),
                        const SizedBox(width: 6),
                        Text('[${entry.tag}]',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.teal)),
                        const Spacer(),
                        Text(
                          '${entry.time.hour.toString().padLeft(2, '0')}:${entry.time.minute.toString().padLeft(2, '0')}:${entry.time.second.toString().padLeft(2, '0')}',
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.message,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDetail(LogEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('[${entry.levelStr}] ${entry.tag}'),
        content: SingleChildScrollView(
          child: SelectableText(
            entry.format(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: entry.format()));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('已复制')),
              );
            },
            child: const Text('复制'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _copyLogs() {
    final text = logger.exportText();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制 ${logger.logs.length} 条日志')),
    );
  }

  void _uploadLogs() async {
    final upload = LogUploadService();
    if (!upload.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先开启「缓存」开关')),
      );
      return;
    }
    if (upload.bufferedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有待上传的日志')),
      );
      return;
    }
    final count = upload.bufferedCount;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在上传 $count 条日志...')),
    );
    final ok = await upload.uploadNow();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '✅ 上传成功 $count 条' : '❌ 上传失败')),
      );
      setState(() {});
    }
  }

  void _clearLogs() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空日志'),
        content: const Text('确定清空所有日志？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
            onPressed: () {
              logger.clear();
              Navigator.pop(ctx);
            },
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
