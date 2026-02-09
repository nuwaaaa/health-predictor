/// 予測結果のデータクラス
/// Firestore: users/{uid}/predictions/{dateKey}
class Prediction {
  final String dateKey;
  final double? pToday; // 今日の不調確率 (0.0〜1.0)
  final double? p3d; // 3日リスク確率 (0.0〜1.0)、開放後のみ
  final String confidence; // 'low', 'medium', 'high'
  final DateTime? generatedAt;
  final String? modelVersion; // 例: 'logistic_v1', 'lgbm_v1'

  Prediction({
    required this.dateKey,
    this.pToday,
    this.p3d,
    this.confidence = 'low',
    this.generatedAt,
    this.modelVersion,
  });

  factory Prediction.fromFirestore(String docId, Map<String, dynamic> data) {
    return Prediction(
      dateKey: docId,
      pToday: (data['pToday'] as num?)?.toDouble(),
      p3d: (data['p3d'] as num?)?.toDouble(),
      confidence: (data['confidence'] as String?) ?? 'low',
      generatedAt: data['generatedAt'] != null
          ? (data['generatedAt'] as dynamic).toDate()
          : null,
      modelVersion: data['modelVersion'] as String?,
    );
  }

  /// 今日のリスクレベルラベル
  String get riskLabel {
    if (pToday == null) return '---';
    final p = pToday!;
    if (p >= 0.6) return '高め';
    if (p >= 0.4) return 'やや注意';
    if (p >= 0.2) return '低め';
    return '良好';
  }

  /// リスクのパーセント表示
  String get riskPercent {
    if (pToday == null) return '--%';
    return '${(pToday! * 100).round()}%';
  }

  /// 3日リスクのパーセント表示
  String get risk3dPercent {
    if (p3d == null) return '--%';
    return '${(p3d! * 100).round()}%';
  }

  /// 信頼度の日本語ラベル
  String get confidenceLabel {
    switch (confidence) {
      case 'high':
        return '高';
      case 'medium':
        return '中';
      default:
        return '低';
    }
  }

  /// 信頼度が低い場合の注記テキスト
  String? get confidenceNote {
    if (confidence == 'low') return 'まだ学習中の参考値です';
    return null;
  }
}
