import 'package:flutter/material.dart';
import '../models/prediction.dart';
import '../models/model_status.dart';

/// 予測結果を表示するカード
class PredictionCard extends StatelessWidget {
  final Prediction? prediction;
  final bool isFallback;
  final ModelStatus status;

  const PredictionCard({
    super.key,
    required this.prediction,
    this.isFallback = false,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    // 14日未満: 学習中表示
    if (!status.ready) {
      return _buildLearningCard();
    }

    // 予測結果がまだ無い場合（バッチ未実行など）
    if (prediction == null || prediction!.pToday == null) {
      return _buildWaitingCard();
    }

    return _buildPredictionCard(context);
  }

  /// 学習中（14日未満）のカード
  Widget _buildLearningCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.model_training, size: 40, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            '予測モデル学習中',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'あと ${status.remainingDays} 日で予測開始',
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          // プログレスバー
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: status.daysCollected / status.daysRequired,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${status.daysCollected} / ${status.daysRequired} 日',
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  /// バッチ未実行・予測結果待ちのカード
  Widget _buildWaitingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: const Column(
        children: [
          Icon(Icons.schedule, size: 36, color: Colors.blueAccent),
          SizedBox(height: 10),
          Text(
            '予測準備中',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            '明朝の更新をお待ちください',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  /// 予測結果カード
  Widget _buildPredictionCard(BuildContext context) {
    final pred = prediction!;
    final pToday = pred.pToday!;
    final riskColor = _riskColor(pToday);
    final showP3d = pred.p3d != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: riskColor.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: riskColor.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー: タイトル + 信頼度
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFallback ? '直近の予測（${_formatDateKey(pred.dateKey)}）' : '今日の不調リスク',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (isFallback)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '今日の予測は明朝更新されます',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ),
                  ],
                ),
              ),
              _confidenceBadge(pred.confidence),
            ],
          ),
          const SizedBox(height: 16),

          // メイン: リスクパーセント + ラベル
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                pred.riskPercent,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: riskColor,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  pred.riskLabel,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: riskColor,
                  ),
                ),
              ),
            ],
          ),

          // 不調基準の要約表示
          if (status.unhealthyThreshold != null) ...[
            const SizedBox(height: 6),
            Text(
              'あなたの基準: 体調 ${status.unhealthyThreshold!.toStringAsFixed(1)} 以下の日',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],

          // 信頼度注記
          if (pred.confidenceNote != null) ...[
            const SizedBox(height: 8),
            Text(
              pred.confidenceNote!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // 特徴量寄与度TOP3
          if (pred.contributions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _contributionsSection(pred),
          ],

          // 改善アドバイス
          if (pred.advices.isNotEmpty) ...[
            const Divider(height: 24),
            _adviceSection(pred),
          ],

          // 3日リスク（開放時のみ）
          if (showP3d) ...[
            const Divider(height: 24),
            _threeDayRisk(pred),
          ],

          // 3日リスク未開放メッセージ
          if (!showP3d && status.daysCollected >= 14) ...[
            const Divider(height: 24),
            _threeDayLocked(),
          ],
        ],
      ),
    );
  }

  /// 3日リスク表示
  Widget _threeDayRisk(Prediction pred) {
    final p3d = pred.p3d!;
    final color = _riskColor(p3d);
    return Row(
      children: [
        const Icon(Icons.calendar_today, size: 16, color: Colors.black54),
        const SizedBox(width: 8),
        const Text(
          '3日間リスク',
          style: TextStyle(fontSize: 14, color: Colors.black87),
        ),
        const Spacer(),
        Text(
          pred.risk3dPercent,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// 3日リスク未開放表示
  Widget _threeDayLocked() {
    final need60 = status.daysCollected < 60;
    final needUnhealthy = status.unhealthyCount < 10;

    String message;
    if (need60) {
      final remaining = 60 - status.daysCollected;
      message = '3日予測はあと $remaining 日で開放';
    } else if (needUnhealthy) {
      message = '3日予測：準備中';
    } else {
      message = '3日予測：まもなく開放';
    }

    return Row(
      children: [
        const Icon(Icons.lock_outline, size: 16, color: Colors.black38),
        const SizedBox(width: 8),
        Text(
          message,
          style: const TextStyle(fontSize: 13, color: Colors.black45),
        ),
      ],
    );
  }

  /// 信頼度バッジ
  Widget _confidenceBadge(String confidence) {
    Color bgColor;
    Color textColor;
    String label;

    switch (confidence) {
      case 'high':
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        label = '信頼度：高';
        break;
      case 'medium':
        bgColor = Colors.amber.shade100;
        textColor = Colors.amber.shade800;
        label = '信頼度：中';
        break;
      default:
        bgColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        label = '信頼度：低';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }

  /// 特徴量寄与度セクション
  Widget _contributionsSection(Prediction pred) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '予測の主な要因',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 6),
        ...pred.contributions.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    c.isRiskIncrease
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 14,
                    color:
                        c.isRiskIncrease ? Colors.red.shade400 : Colors.green.shade400,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    c.label,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.isRiskIncrease
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  /// 改善アドバイスセクション
  Widget _adviceSection(Prediction pred) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber.shade700),
            const SizedBox(width: 6),
            Text(
              '改善アドバイス',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.amber.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...pred.advices.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('・', style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      a.message,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  /// dateKey (yyyy-MM-dd) を M/d 形式に変換
  String _formatDateKey(String dateKey) {
    try {
      final parts = dateKey.split('-');
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      return '$month/$day';
    } catch (_) {
      return dateKey;
    }
  }

  /// リスクレベルに応じた色
  Color _riskColor(double p) {
    if (p >= 0.6) return Colors.red.shade700;
    if (p >= 0.4) return Colors.orange.shade700;
    if (p >= 0.2) return Colors.amber.shade700;
    return Colors.green.shade700;
  }
}
