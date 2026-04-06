import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

/// プライバシーオンボーディング（初回起動時のみ表示）
/// 設計書 Section 15.1 に基づく
class OnboardingPage extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingPage({super.key, required this.onComplete});

  static const _prefKey = 'onboarding_completed';

  /// オンボーディング済みかどうか
  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// オンボーディング完了を記録（同意情報も保存）
  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
    await prefs.setString('consent_version', '1.0');
    await prefs.setString('consent_date', DateTime.now().toIso8601String());
    await prefs.setBool('consent_pending_sync', true);
  }

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool _privacyChecked = false;
  bool _termsChecked = false;

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canProceed = _privacyChecked && _termsChecked;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 1),
              const Center(
                child: Text(
                  'あなたのデータについて',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 36),
              _infoRow(
                context,
                icon: Icons.bar_chart_rounded,
                title: '何を記録するか',
                description: '体調・睡眠・歩数・ストレス',
              ),
              const SizedBox(height: 24),
              _infoRow(
                context,
                icon: Icons.lock_outline,
                title: 'どこに保存されるか',
                description: 'あなた専用のクラウド\n（インターネット上の安全な保管場所）',
              ),
              const SizedBox(height: 24),
              _infoRow(
                context,
                icon: Icons.delete_outline,
                title: 'いつでも削除できます',
                description: '設定 → アカウント削除で\nすべてのデータを完全に削除',
              ),
              const Spacer(flex: 2),

              // --- 同意チェックボックス ---
              _consentRow(
                checked: _privacyChecked,
                onChanged: (v) => setState(() => _privacyChecked = v ?? false),
                label: 'プライバシーポリシー',
                url: 'https://nuwaaaa.github.io/health-predictor/privacy',
              ),
              const SizedBox(height: 12),
              _consentRow(
                checked: _termsChecked,
                onChanged: (v) => setState(() => _termsChecked = v ?? false),
                label: '利用規約',
                url: 'https://nuwaaaa.github.io/health-predictor/terms',
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: canProceed
                      ? () async {
                          await OnboardingPage.markCompleted();
                          widget.onComplete();
                        }
                      : null,
                  child: const Text('はじめる', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _consentRow({
    required bool checked,
    required ValueChanged<bool?> onChanged,
    required String label,
    required String url,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: checked,
          onChanged: onChanged,
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => _launchUrl(url),
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: context.textSubColor),
                children: [
                  TextSpan(
                    text: label,
                    style: TextStyle(
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const TextSpan(text: 'に同意する'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.primaryTintColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 24, color: AppColors.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.textMainColor),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                    fontSize: 14, color: context.textSubColor, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
