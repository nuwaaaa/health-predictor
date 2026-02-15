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
  });

  factory ModelStatus.fromFirestore(Map<String, dynamic> data) {
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
