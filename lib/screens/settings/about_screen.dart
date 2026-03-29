import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/settings/setting_store.dart';
import 'package:provider/provider.dart';

/// 关于页面
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _appVersion = '1.0.0';
  static const _githubUrl = 'https://github.com/bmbxwbh/luo_xue_next';
  static const _giteeUrl = 'https://gitee.com/bmbxwbh/luo_xue_next';
  static const _lxOriginalUrl = 'https://github.com/lyswhut/lx-music-mobile';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const SizedBox(height: 24),
          // Logo + 名称
          Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  size: 40,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '洛雪NEXT',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'v$_appVersion',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 软件介绍
          _buildSection(context, '软件介绍', [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '洛雪NEXT 是一款基于 Flutter 开发的跨平台音乐播放器，灵感来源于洛雪音乐助手。'
                '本软件支持多个音乐平台的搜索与播放，致力于为用户提供简洁、流畅的音乐体验。',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                '本软件完全免费开源，仅供学习交流使用。请勿用于任何商业用途。',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ]),

          // 开源地址
          _buildSection(context, '开源仓库', [
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('GitHub'),
              subtitle: Text(_githubUrl.replaceFirst('https://', '')),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _launchUrl(_githubUrl),
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Gitee（国内镜像）'),
              subtitle: Text(_giteeUrl.replaceFirst('https://', '')),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _launchUrl(_giteeUrl),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('洛雪音乐助手（原版）'),
              subtitle: Text(_lxOriginalUrl.replaceFirst('https://', '')),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _launchUrl(_lxOriginalUrl),
            ),
          ]),

          // 免责协议
          _buildSection(context, '法律信息', [
            ListTile(
              leading: const Icon(Icons.gavel),
              title: const Text('免责声明'),
              subtitle: const Text('点击查看完整免责协议'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDisclaimerDialog(context),
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('开源许可证'),
              subtitle: const Text('MIT License'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLicenseDialog(context),
            ),
          ]),

          // 致谢
          _buildSection(context, '致谢', [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '• 洛雪音乐助手 — 项目的灵感来源\n'
                '• 所有开源社区的贡献者\n'
                '• 所有使用和支持本项目的用户',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// 免责协议弹窗
  static void showDisclaimerIfNeeded(BuildContext context, SettingStore store) {
    if (!store.disclaimerAccepted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDisclaimerDialog(context);
      });
    }
  }

  static void _showDisclaimerDialog(BuildContext context) {
    final store = context.read<SettingStore>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.gavel, size: 22),
            SizedBox(width: 8),
            Text('免责声明'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            '欢迎使用洛雪NEXT（以下简称"本软件"）。在使用本软件之前，请您仔细阅读以下免责条款：\n\n'
            '一、软件性质\n'
            '本软件是一款开源的音乐播放器客户端，仅提供音乐搜索和播放功能的入口，'
            '不存储、上传或分发任何音频文件。所有音乐内容均来自第三方平台。\n\n'
            '二、版权声明\n'
            '本软件仅供学习交流使用，不得用于任何商业用途。'
            '所有音乐内容的版权归各音乐平台及版权方所有。'
            '如果您是版权所有者，认为本软件侵犯了您的权益，请联系我们处理。\n\n'
            '三、免责声明\n'
            '1. 本软件按"现状"提供，不对软件的功能、准确性、可靠性做任何保证。\n'
            '2. 因使用本软件而产生的任何直接或间接损失，本软件开发者不承担任何责任。\n'
            '3. 用户使用本软件所获取的任何内容，由内容提供方承担全部责任。\n'
            '4. 用户应自行承担使用本软件的风险。\n\n'
            '四、隐私保护\n'
            '本软件不会收集、存储或上传用户的个人信息。用户的使用数据仅存储在本地设备上。\n\n'
            '五、其他\n'
            '本免责声明的最终解释权归本软件开发者所有。开发者有权在必要时修改本声明。\n\n'
            '使用本软件即表示您已阅读、理解并同意上述免责声明的全部内容。',
            style: TextStyle(fontSize: 14, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 如果是首次同意，需要存储
              if (!store.disclaimerAccepted) {
                store.setDisclaimerAccepted(true);
              }
            },
            child: const Text('我已阅读并同意'),
          ),
        ],
      ),
    );
  }

  void _showLicenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('MIT License'),
        content: const SingleChildScrollView(
          child: Text(
            'MIT License\n\n'
            'Copyright (c) 2026 luo_xue_next contributors\n\n'
            'Permission is hereby granted, free of charge, to any person obtaining a copy '
            'of this software and associated documentation files (the "Software"), to deal '
            'in the Software without restriction, including without limitation the rights '
            'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell '
            'copies of the Software, and to permit persons to whom the Software is '
            'furnished to do so, subject to the following conditions:\n\n'
            'The above copyright notice and this permission notice shall be included in all '
            'copies or substantial portions of the Software.\n\n'
            'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR '
            'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, '
            'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE '
            'AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER '
            'LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, '
            'OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE '
            'SOFTWARE.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
