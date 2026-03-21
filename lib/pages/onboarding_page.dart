import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// プライバシーオンボーディング（初回起動時のみ表示）
/// 設計書 Section 15.1 に基づく
class OnboardingPage extends StatelessWidget {
  final VoidCallback onComplete;

  const OnboardingPage({super.key, required this.onComplete});

  static const _prefKey = 'onboarding_completed';

  /// オンボーディング済みかどうか
  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// オンボーディング完了を記録
  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  @override
  Widget build(BuildContext context) {
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
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () async {
                    await markCompleted();
                    onComplete();
                  },
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
