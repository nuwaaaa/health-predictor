import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// 設定タブ: ヘルスケア連携、通知設定、プライバシー、アカウント
class SettingsPage extends StatefulWidget {
  final AuthService authService;
  final FirestoreService service;
  final Future<void> Function() onReload;

  const SettingsPage({
    super.key,
    required this.authService,
    required this.service,
    required this.onReload,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _seeding = false;

  Future<void> _showSeedDialog() async {
    final days = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('テストデータ作成'),
        children: [
          _seedOption(context, 7, '7日（学習中）'),
          _seedOption(context, 30, '30日（今日リスクのみ）'),
          _seedOption(context, 100, '100日（3日リスクも表示）'),
        ],
      ),
    );
    if (days != null) await _seedTestData(days);
  }

  Widget _seedOption(BuildContext context, int days, String label) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(context, days),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Future<void> _seedTestData(int days) async {
    setState(() => _seeding = true);
    try {
      await widget.service.seedTestData(totalDays: days);
      await widget.onReload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${days}日分のテストデータを作成しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('作成失敗: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),

          // --- ヘルスケア連携 ---
          _sectionTitle('ヘルスケア連携'),
          const SizedBox(height: 10),
          _settingCard(
            icon: Icons.favorite_outline,
            title: 'Apple Health / Google Fit',
            subtitle: '睡眠・歩数の自動取得',
            trailing: const Icon(Icons.chevron_right, color: Colors.black38),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('ヘルスケア連携は入力画面の「自動取得」から利用できます')),
              );
            },
          ),

          const SizedBox(height: 24),

          // --- 通知設定 ---
          _sectionTitle('通知設定'),
          const SizedBox(height: 10),
          _settingCard(
            icon: Icons.notifications_outlined,
            title: '入力リマインダー',
            subtitle: '毎日の記録を忘れないように通知',
            trailing: const Text('準備中',
                style: TextStyle(fontSize: 12, color: Colors.black38)),
          ),

          const SizedBox(height: 24),

          // --- プライバシー ---
          _sectionTitle('プライバシー'),
          const SizedBox(height: 10),
          _settingCard(
            icon: Icons.shield_outlined,
            title: '学習データの確認・削除',
            subtitle: '収集されたデータを確認・管理',
            trailing: const Text('準備中',
                style: TextStyle(fontSize: 12, color: Colors.black38)),
          ),

          const SizedBox(height: 24),

          // --- アカウント ---
          _sectionTitle('アカウント'),
          const SizedBox(height: 10),
          _settingCard(
            icon: Icons.logout,
            title: 'ログアウト',
            subtitle: '',
            onTap: () => widget.authService.signOut(),
          ),

          const SizedBox(height: 24),

          // --- 開発用 ---
          _sectionTitle('開発用'),
          const SizedBox(height: 10),
          _settingCard(
            icon: Icons.bug_report_outlined,
            title: 'テストデータ作成',
            subtitle: '開発・デバッグ用のサンプルデータを生成',
            trailing: _seeding
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right, color: Colors.black38),
            onTap: _seeding ? null : _showSeedDialog,
          ),

          const SizedBox(height: 30),
        ],
      ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _settingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: Colors.black54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black45)),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}
