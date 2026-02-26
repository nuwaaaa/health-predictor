/// クライアント側推論用モデルパラメータ（ロジスティック回帰）
class ModelParams {
  final List<double> coefficients;
  final double intercept;
  final List<double> scalerMean;
  final List<double> scalerScale;
  final List<String> featureColumns;

  ModelParams({
    required this.coefficients,
    required this.intercept,
    required this.scalerMean,
    required this.scalerScale,
    required this.featureColumns,
  });

  factory ModelParams.fromFirestore(Map<String, dynamic> data) {
    return ModelParams(
      coefficients: (data['coefficients'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      intercept: (data['intercept'] as num).toDouble(),
      scalerMean: (data['scalerMean'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      scalerScale: (data['scalerScale'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      featureColumns: (data['featureColumns'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }
}

/// モデル状態のデータクラス
/// Firestore: users/{uid}/model_status/current
class ModelStatus {
  final int daysCollected;
  final int daysRequired;
  final bool ready;
  final int unhealthyCount;
  final double recentMissingRate;
  final String modelType; // 'logistic' or 'lightgbm'
  final String confidenceLevel; // 'low', 'medium', 'high'
  final double? moodMean14; // 直近14日の体調平均
  final double? unhealthyThreshold; // 不調閾値（moodMean14 - 1）
  final ModelParams? modelParams; // クライアント側推論用（logisticのみ）

  ModelStatus({
    this.daysCollected = 0,
    this.daysRequired = 14,
    this.ready = false,
    this.unhealthyCount = 0,
    this.recentMissingRate = 0.0,
    this.modelType = 'logistic',
    this.confidenceLevel = 'low',
    this.moodMean14,
    this.unhealthyThreshold,
    this.modelParams,
  });

  factory ModelStatus.fromFirestore(Map<String, dynamic> data) {
    ModelParams? params;
    if (data['modelParams'] is Map<String, dynamic>) {
      try {
        params = ModelParams.fromFirestore(
            data['modelParams'] as Map<String, dynamic>);
      } catch (_) {
        // パース失敗時はnull（クライアント予測無効化）
      }
    }

    return ModelStatus(
      daysCollected: (data['daysCollected'] as int?) ?? 0,
      daysRequired: (data['daysRequired'] as int?) ?? 14,
      ready: (data['ready'] as bool?) ?? false,
      unhealthyCount: (data['unhealthyCount'] as int?) ?? 0,
      recentMissingRate: (data['recentMissingRate'] as num?)?.toDouble() ?? 0.0,
      modelType: (data['modelType'] as String?) ?? 'logistic',
      confidenceLevel: (data['confidenceLevel'] as String?) ?? 'low',
      moodMean14: (data['moodMean14'] as num?)?.toDouble(),
      unhealthyThreshold: (data['unhealthyThreshold'] as num?)?.toDouble(),
      modelParams: params,
    );
  }

  int get remainingDays =>
      (daysRequired - daysCollected).clamp(0, daysRequired);

  String get statusLabel {
    if (ready) return '予測機能：利用可能';
    return '学習中（あと $remainingDays 日）';
  }

  String get confidenceLevelLabel {
    switch (confidenceLevel) {
      case 'high':
        return '高';
      case 'medium':
        return '中';
      default:
        return '低';
    }
  }

  /// 3日リスクが開放条件を満たしているか
  bool get is3dReady => daysCollected >= 60 && unhealthyCount >= 10;
}
