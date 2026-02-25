import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// 設定タブ: アカウント連携、ヘルスケア連携、通知設定、プライバシー、アカウント
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
  bool _linking = false;
  bool _deleting = false;

  // ---------------------------------------------------------------------------
  // アカウント連携
  // ---------------------------------------------------------------------------

  Future<void> _linkWithGoogle() async {
    setState(() => _linking = true);
    try {
      await widget.authService.linkWithGoogle();
      if (mounted) {
        _showSnack('Googleアカウントを連携しました');
        setState(() {});
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(_linkErrorMessage(e.code));
    } catch (e) {
      _showSnack('連携失敗: $e');
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  Future<void> _linkWithApple() async {
    setState(() => _linking = true);
    try {
      await widget.authService.linkWithApple();
      if (mounted) {
        _showSnack('Appleアカウントを連携しました');
        setState(() {});
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(_linkErrorMessage(e.code));
    } catch (e) {
      _showSnack('連携失敗: $e');
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  Future<void> _linkWithEmail() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _EmailLinkDialog(),
    );
    if (result == null) return;

    setState(() => _linking = true);
    try {
      await widget.authService.linkWithEmail(
        email: result['email']!,
        password: result['password']!,
      );
      if (mounted) {
        _showSnack('メールアドレスを連携しました');
        setState(() {});
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(_linkErrorMessage(e.code));
    } catch (e) {
      _showSnack('連携失敗: $e');
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  String _linkErrorMessage(String code) {
    switch (code) {
      case 'credential-already-in-use':
        return 'このアカウントは既に別のユーザーに連携されています';
      case 'email-already-in-use':
        return 'このメールアドレスは既に使用されています';
      case 'provider-already-linked':
        return 'この認証方式は既に連携済みです';
      default:
        return '連携エラーが発生しました';
    }
  }

  // ---------------------------------------------------------------------------
  // アカウント削除
  // ---------------------------------------------------------------------------

  Future<void> _showDeleteAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アカウントを削除'),
        content: const Text(
          'すべてのデータが完全に削除されます。この操作は取り消せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    setState(() => _deleting = true);
    try {
      // 匿名ユーザーは再認証不要
      if (!widget.authService.isAnonymous) {
        await _reauthenticate();
      }

      // 1. Firestore のユーザーデータ削除
      await widget.service.deleteAllUserData();

      // 2. Firebase Auth のアカウント削除
      await widget.authService.deleteAccount();

      // 3. ローカルデータ削除（設計書 Section 15.2）
      // Firestoreのオフラインキャッシュをクリア
      try {
        await FirebaseFirestore.instance.terminate();
        await FirebaseFirestore.instance.clearPersistence();
      } catch (_) {
        // キャッシュクリア失敗は致命的でないため無視
      }

      // 4. 削除後は AuthWrapper が自動でログイン画面へ遷移
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showSnack('再認証が必要です。再度お試しください。');
      } else {
        _showSnack('削除失敗: ${e.message}');
      }
    } catch (e) {
      _showSnack('削除失敗: $e');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _reauthenticate() async {
    final providers = widget.authService.linkedProviders;

    if (providers.contains('google.com')) {
      await widget.authService.reauthenticateWithGoogle();
    } else if (providers.contains('apple.com')) {
      await widget.authService.reauthenticateWithApple();
    } else if (providers.contains('password')) {
      // メール/パスワードの場合はダイアログで入力してもらう
      if (!mounted) return;
      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => const _ReauthEmailDialog(),
      );
      if (result == null) throw Exception('再認証がキャンセルされました');
      await widget.authService.reauthenticateWithEmail(
        email: result['email']!,
        password: result['password']!,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // テストデータ
  // ---------------------------------------------------------------------------

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
        _showSnack('${days}日分のテストデータを作成しました');
      }
    } catch (e) {
      if (mounted) _showSnack('作成失敗: $e');
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAnon = widget.authService.isAnonymous;
    final providers = widget.authService.linkedProviders;
    final hasGoogle = providers.contains('google.com');
    final hasApple = providers.contains('apple.com');
    final hasEmail = providers.contains('password');

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

            // --- 匿名ユーザーへの連携促進バナー ---
            if (isAnon) ...[
              _anonymousBanner(),
              const SizedBox(height: 24),
            ],

            // --- アカウント連携 ---
            if (isAnon) ...[
              _sectionTitle('アカウント連携'),
              const SizedBox(height: 6),
              Text(
                '連携するとアプリを削除してもデータを復元できます',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),
              if (defaultTargetPlatform == TargetPlatform.iOS && !hasApple)
                _settingCard(
                  icon: Icons.apple,
                  title: 'Appleで連携',
                  subtitle: '',
                  trailing: _linking
                      ? const _SmallSpinner()
                      : const Icon(Icons.chevron_right, color: Colors.black38),
                  onTap: _linking ? null : _linkWithApple,
                ),
              if (!hasGoogle) ...[
                const SizedBox(height: 8),
                _settingCard(
                  icon: Icons.g_mobiledata,
                  title: 'Googleで連携',
                  subtitle: '',
                  trailing: _linking
                      ? const _SmallSpinner()
                      : const Icon(Icons.chevron_right, color: Colors.black38),
                  onTap: _linking ? null : _linkWithGoogle,
                ),
              ],
              if (!hasEmail) ...[
                const SizedBox(height: 8),
                _settingCard(
                  icon: Icons.email_outlined,
                  title: 'メールアドレスで連携',
                  subtitle: '',
                  trailing: _linking
                      ? const _SmallSpinner()
                      : const Icon(Icons.chevron_right, color: Colors.black38),
                  onTap: _linking ? null : _linkWithEmail,
                ),
              ],
              const SizedBox(height: 24),
            ],


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

            // --- ログアウト ---
            _settingCard(
              icon: Icons.logout,
              title: 'ログアウト',
              subtitle: '',
              onTap: () => widget.authService.signOut(),
            ),

            const SizedBox(height: 12),

            // --- アカウント削除 ---
            _settingCard(
              icon: Icons.delete_forever_outlined,
              title: 'アカウントを削除',
              subtitle: 'すべてのデータが完全に削除されます',
              titleColor: Colors.red,
              trailing: _deleting
                  ? const _SmallSpinner()
                  : const Icon(Icons.chevron_right, color: Colors.red),
              onTap: _deleting ? null : _showDeleteAccountDialog,
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
                  ? const _SmallSpinner()
                  : const Icon(Icons.chevron_right, color: Colors.black38),
              onTap: _seeding ? null : _showSeedDialog,
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  /// 匿名ユーザーへのバナー
  Widget _anonymousBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 28, color: Colors.amber.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('アカウント未連携',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'アプリを削除するとデータにアクセスできなくなります。アカウントを連携してデータを保護しましょう。',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
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
    Color? titleColor,
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
            Icon(icon, size: 24, color: titleColor ?? Colors.black54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: titleColor)),
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

// =============================================================================
// ダイアログ
// =============================================================================

/// メール連携用ダイアログ
class _EmailLinkDialog extends StatefulWidget {
  const _EmailLinkDialog();

  @override
  State<_EmailLinkDialog> createState() => _EmailLinkDialogState();
}

class _EmailLinkDialogState extends State<_EmailLinkDialog> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('メールアドレスで連携'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'メールアドレス'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'パスワード（6文字以上）'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () {
            final email = _emailCtrl.text.trim();
            final pass = _passCtrl.text.trim();
            if (email.isEmpty || pass.isEmpty) return;
            Navigator.pop(context, {'email': email, 'password': pass});
          },
          child: const Text('連携する'),
        ),
      ],
    );
  }
}

/// 再認証用メールダイアログ
class _ReauthEmailDialog extends StatefulWidget {
  const _ReauthEmailDialog();

  @override
  State<_ReauthEmailDialog> createState() => _ReauthEmailDialogState();
}

class _ReauthEmailDialogState extends State<_ReauthEmailDialog> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('再認証'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('セキュリティのため、認証情報を再入力してください。',
              style: TextStyle(fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'メールアドレス'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'パスワード'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () {
            final email = _emailCtrl.text.trim();
            final pass = _passCtrl.text.trim();
            if (email.isEmpty || pass.isEmpty) return;
            Navigator.pop(context, {'email': email, 'password': pass});
          },
          child: const Text('確認'),
        ),
      ],
    );
  }
}

/// 小さいスピナー
class _SmallSpinner extends StatelessWidget {
  const _SmallSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
