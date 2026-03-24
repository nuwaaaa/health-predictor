import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kDebugMode, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show themeNotifier;
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/health_sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// 設定タブ — Calm Blue デザイン
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
  bool _autoSyncEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadAutoSyncPref();
  }

  Future<void> _loadAutoSyncPref() async {
    final enabled = await HealthSyncService.isAutoSyncEnabled();
    if (mounted) setState(() => _autoSyncEnabled = enabled);
  }

  Future<void> _toggleAutoSync(bool value) async {
    setState(() => _autoSyncEnabled = value);
    await HealthSyncService.setAutoSyncEnabled(value);
  }

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
      developer.log('Google連携エラー: code=${e.code}, message=${e.message}',
          name: 'SettingsPage');
      _showSnack(_linkErrorMessage(e.code));
    } catch (e) {
      developer.log('Google連携エラー(不明): $e', name: 'SettingsPage');
      _showSnack('連携に失敗しました。しばらくしてから再度お試しください');
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
      developer.log('Apple連携エラー: code=${e.code}, message=${e.message}',
          name: 'SettingsPage');
      _showSnack(_linkErrorMessage(e.code));
    } catch (e) {
      developer.log('Apple連携エラー(不明): $e', name: 'SettingsPage');
      _showSnack('連携に失敗しました。しばらくしてから再度お試しください');
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
      _showSnack('連携に失敗しました。しばらくしてから再度お試しください');
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
      case 'user-cancelled':
      case 'web-context-cancelled':
        return '連携がキャンセルされました';
      case 'network-request-failed':
        return 'ネットワーク接続を確認してください';
      case 'invalid-credential':
        return '認証情報が無効です。再度お試しください';
      default:
        return '連携エラーが発生しました（$code）';
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
            style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
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
      if (!widget.authService.isAnonymous) {
        await _reauthenticate();
      }
      await widget.service.deleteAllUserData();
      await widget.authService.deleteAccount();
      try {
        await FirebaseFirestore.instance.terminate();
        await FirebaseFirestore.instance.clearPersistence();
      } catch (_) {}
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showSnack('再認証が必要です。再度お試しください。');
      } else {
        _showSnack('削除に失敗しました。しばらくしてから再度お試しください');
      }
    } catch (e) {
      developer.log('アカウント削除エラー: $e', name: 'SettingsPage');
      _showSnack('削除に失敗しました。しばらくしてから再度お試しください');
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
          _seedOption(context, 100, '100日（3日以内リスクも表示）'),
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
        child: Text(label, style: AppTextStyles.body),
      ),
    );
  }

  Future<void> _seedTestData(int days) async {
    setState(() => _seeding = true);
    try {
      await widget.service.seedTestData(totalDays: days);
      await widget.onReload();
      if (mounted) {
        _showSnack('$days日分のテストデータを作成しました');
      }
    } catch (e) {
      developer.log('テストデータ作成失敗: $e', name: 'SettingsPage');
      if (mounted) _showSnack('テストデータの作成に失敗しました');
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
      appBar: AppBar(title: const Text('設定')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.md),

            // --- 匿名ユーザーへの連携促進バナー ---
            if (isAnon) ...[
              _anonymousBanner(),
              const SizedBox(height: AppSpacing.lg),
            ],

            // --- アカウント連携 ---
            if (isAnon) ...[
              SectionHeader(title: 'アカウント連携'),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '連携するとアプリを削除してもデータを復元できます',
                style: AppTextStyles.captionSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (defaultTargetPlatform == TargetPlatform.iOS && !hasApple)
                _settingCard(
                  icon: Icons.apple,
                  title: 'Appleで連携',
                  subtitle: '',
                  trailing: _linking
                      ? const _SmallSpinner()
                      : Icon(Icons.chevron_right, color: context.textSubColor),
                  onTap: _linking ? null : _linkWithApple,
                ),
              if (!hasGoogle) ...[
                const SizedBox(height: AppSpacing.sm),
                _settingCard(
                  icon: Icons.g_mobiledata,
                  title: 'Googleで連携',
                  subtitle: '',
                  trailing: _linking
                      ? const _SmallSpinner()
                      : Icon(Icons.chevron_right, color: context.textSubColor),
                  onTap: _linking ? null : _linkWithGoogle,
                ),
              ],
              if (!hasEmail) ...[
                const SizedBox(height: AppSpacing.sm),
                _settingCard(
                  icon: Icons.email_outlined,
                  title: 'メールアドレスで連携',
                  subtitle: '',
                  trailing: _linking
                      ? const _SmallSpinner()
                      : Icon(Icons.chevron_right, color: context.textSubColor),
                  onTap: _linking ? null : _linkWithEmail,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
            ],

            // --- データ同期 ---
            SectionHeader(title: 'データ同期'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Row(
                children: [
                  Icon(Icons.sync, size: 24, color: context.textSubColor),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ヘルスデータ自動同期',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: context.textMainColor)),
                        Text('歩数・睡眠を自動で取得',
                            style: AppTextStyles.captionSmall),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _autoSyncEnabled,
                    onChanged: _toggleAutoSync,
                    activeTrackColor: AppColors.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // --- テーマ ---
            SectionHeader(title: '外観'),
            const SizedBox(height: AppSpacing.sm),
            _themeSelector(),

            const SizedBox(height: AppSpacing.lg),

            // --- プライバシー ---
            SectionHeader(title: 'プライバシー'),
            const SizedBox(height: AppSpacing.sm),
            _settingCard(
              icon: Icons.description_outlined,
              title: 'プライバシーポリシー',
              subtitle: 'データの取り扱いについて',
              trailing: Icon(Icons.open_in_new, size: 18, color: context.textSubColor),
              onTap: () {
                // TODO: プライバシーポリシーURLが確定したら更新する
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('プライバシーポリシーは準備中です')),
                );
              },
            ),

            const SizedBox(height: AppSpacing.lg),

            // --- ログアウト ---
            _settingCard(
              icon: Icons.logout,
              title: 'ログアウト',
              subtitle: '',
              onTap: () => widget.authService.signOut(),
            ),

            const SizedBox(height: AppSpacing.sm),

            // --- アカウント削除 ---
            _settingCard(
              icon: Icons.delete_forever_outlined,
              title: 'アカウントを削除',
              subtitle: 'すべてのデータが完全に削除されます',
              titleColor: AppColors.destructive,
              trailing: _deleting
                  ? const _SmallSpinner()
                  : const Icon(Icons.chevron_right, color: AppColors.destructive),
              onTap: _deleting ? null : _showDeleteAccountDialog,
            ),

            const SizedBox(height: AppSpacing.lg),

            // --- 開発用（デバッグビルドのみ） ---
            if (kDebugMode) ...[
              SectionHeader(title: '開発用'),
              const SizedBox(height: AppSpacing.sm),
              _settingCard(
                icon: Icons.bug_report_outlined,
                title: 'テストデータ作成',
                subtitle: '開発・デバッグ用のサンプルデータを生成',
                trailing: _seeding
                    ? const _SmallSpinner()
                    : Icon(Icons.chevron_right, color: context.textSubColor),
                onTap: _seeding ? null : _showSeedDialog,
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  /// 匿名ユーザーへのバナー
  Widget _anonymousBanner() {
    return AccentCard(
      accentColor: AppColors.cautionSoft2,
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 28, color: AppColors.chartOrange),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('アカウント未連携',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textMainColor)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'アプリを削除するとデータにアクセスできなくなります。アカウントを連携してデータを保護しましょう。',
                  style: AppTextStyles.captionSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeSelector() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.palette_outlined, size: 24, color: context.textSubColor),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text('テーマ',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.textMainColor)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _themeChip(
                    label: 'ライト',
                    icon: Icons.light_mode,
                    mode: ThemeMode.light,
                    currentMode: currentMode,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _themeChip(
                    label: 'ダーク',
                    icon: Icons.dark_mode,
                    mode: ThemeMode.dark,
                    currentMode: currentMode,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _themeChip(
                    label: '自動',
                    icon: Icons.settings_brightness,
                    mode: ThemeMode.system,
                    currentMode: currentMode,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _themeChip({
    required String label,
    required IconData icon,
    required ThemeMode mode,
    required ThemeMode currentMode,
  }) {
    final selected = mode == currentMode;
    return Expanded(
      child: GestureDetector(
        onTap: () => themeNotifier.setThemeMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? context.primaryTintColor : context.bgColor,
            borderRadius: BorderRadius.circular(AppRadii.button),
            border: Border.all(
              color: selected ? AppColors.primary : context.dividerColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20,
                  color: selected ? AppColors.primary : context.textSubColor),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? AppColors.primary : context.textSubColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 24, color: titleColor ?? context.textSubColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: titleColor ?? context.textMainColor)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: AppTextStyles.captionSmall),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}

// =============================================================================
// ダイアログ
// =============================================================================

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
