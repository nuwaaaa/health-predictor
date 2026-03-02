/// 予測結果のデータクラス
/// Firestore: users/{uid}/predictions/{dateKey}
class Prediction {
  final String dateKey;
  final double? pToday; // 今日の不調確率 (0.0〜1.0)
  final double? p3d; // 3日リスク確率 (0.0〜1.0)、開放後のみ
  final String confidence; // 'low', 'medium', 'high'
  final DateTime? generatedAt;
  final String? modelVersion; // 例: 'logistic_v1', 'lgbm_v1'
  final List<FeatureContribution> contributions; // 寄与度TOP3
  final List<Advice> advices; // 改善アドバイス（最大2件）
  final bool provisional; // オンデマンド生成の暫定フラグ
  final String? source; // 'batch', 'on_demand_edit', 'on_demand_input'

  Prediction({
    required this.dateKey,
    this.pToday,
    this.p3d,
    this.confidence = 'low',
    this.generatedAt,
    this.modelVersion,
    this.contributions = const [],
    this.advices = const [],
    this.provisional = false,
    this.source,
  });

  factory Prediction.fromFirestore(String docId, Map<String, dynamic> data) {
    final contribRaw = data['contributions'] as List<dynamic>? ?? [];
    final adviceRaw = data['advices'] as List<dynamic>? ?? [];

    return Prediction(
      dateKey: docId,
      pToday: (data['pToday'] as num?)?.toDouble(),
      p3d: (data['p3d'] as num?)?.toDouble(),
      confidence: (data['confidence'] as String?) ?? 'low',
      generatedAt: data['generatedAt'] != null
          ? (data['generatedAt'] as dynamic).toDate()
          : null,
      modelVersion: data['modelVersion'] as String?,
      contributions: contribRaw
          .map((e) =>
              FeatureContribution.fromMap(e as Map<String, dynamic>))
          .toList(),
      advices: adviceRaw
          .map((e) => Advice.fromMap(e as Map<String, dynamic>))
          .toList(),
      provisional: (data['provisional'] as bool?) ?? false,
      source: data['source'] as String?,
    );
  }

  /// 信頼度lowのとき確率を 0.15〜0.65 にクリップ（設計書 Section 11.2）
  double? get displayPToday {
    if (pToday == null) return null;
    if (confidence == 'low') return pToday!.clamp(0.15, 0.65);
    return pToday;
  }

  /// 3日リスクの表示用（同様にクリップ）
  double? get displayP3d {
    if (p3d == null) return null;
    if (confidence == 'low') return p3d!.clamp(0.15, 0.65);
    return p3d;
  }

  /// 今日のリスクレベルラベル（クリップ後の値で判定）
  String get riskLabel {
    final p = displayPToday;
    if (p == null) return '---';
    if (p >= 0.6) return '高め';
    if (p >= 0.4) return 'やや注意';
    if (p >= 0.2) return '低め';
    return '良好';
  }

  /// 3日以内リスクのレベルラベル（クリップ後の値で判定）
  String get risk3dLabel {
    final p = displayP3d;
    if (p == null) return '---';
    if (p >= 0.6) return '高め';
    if (p >= 0.4) return 'やや注意';
    if (p >= 0.2) return '低め';
    return '良好';
  }

  /// リスクのパーセント表示（クリップ後）
  String get riskPercent {
    if (displayPToday == null) return '--%';
    return '${(displayPToday! * 100).round()}%';
  }

  /// 3日リスクのパーセント表示（クリップ後）
  String get risk3dPercent {
    if (displayP3d == null) return '--%';
    return '${(displayP3d! * 100).round()}%';
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
    if (confidence == 'low') {
      return '参考値です。データが増えるほど精度が上がります';
    }
    return null;
  }
}

/// 特徴量寄与度
class FeatureContribution {
  final String feature;
  final double value; // 正=リスク増加, 負=リスク低下

  FeatureContribution({required this.feature, required this.value});

  factory FeatureContribution.fromMap(Map<String, dynamic> map) {
    return FeatureContribution(
      feature: map['feature'] as String? ?? '',
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// 特徴量名を日本語に変換
  String get label {
    const labels = {
      'mood_lag1': '前日の体調',
      'mood_ma3': '体調(3日平均)',
      'mood_ma7': '体調(7日平均)',
      'mood_delta1': '体調の変化',
      'mood_dev14': '体調(14日偏差)',
      'sleep_hours_filled': '睡眠時間',
      'sleep_missing': '睡眠データ欠損',
      'sleep_dev': '睡眠(偏差)',
      'steps_filled': '歩数',
      'steps_missing': '歩数データ欠損',
      'steps_dev': '歩数(偏差)',
      'stress_filled': 'ストレス',
      'stress_missing': 'ストレス欠損',
      'day_of_week': '曜日',
      'is_weekend': '休日',
    };
    return labels[feature] ?? feature;
  }

  /// リスク増加方向かどうか
  bool get isRiskIncrease => value > 0;
}

/// 改善アドバイス
class Advice {
  final String param; // 'sleep', 'steps', 'stress'
  final String message;

  Advice({required this.param, required this.message});

  factory Advice.fromMap(Map<String, dynamic> map) {
    return Advice(
      param: map['param'] as String? ?? '',
      message: map['message'] as String? ?? '',
    );
  }
}
