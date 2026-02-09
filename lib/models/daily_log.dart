/// 日次ログのデータクラス
/// Firestore: users/{uid}/daily/{dateKey}
class DailyLog {
  final String dateKey; // YYYY-MM-DD（起床日ベース）
  final int? moodScore; // 1〜5
  final SleepData? sleep;
  final int? steps;
  final int? stress; // 1〜5（任意）
  final String? tzAtWake; // 例: Asia/Tokyo
  final DateTime? updatedAt;

  DailyLog({
    required this.dateKey,
    this.moodScore,
    this.sleep,
    this.steps,
    this.stress,
    this.tzAtWake,
    this.updatedAt,
  });

  factory DailyLog.fromFirestore(String docId, Map<String, dynamic> data) {
    SleepData? sleep;
    if (data['sleep'] is Map<String, dynamic>) {
      sleep = SleepData.fromMap(data['sleep'] as Map<String, dynamic>);
    }

    return DailyLog(
      dateKey: docId,
      moodScore: data['moodScore'] as int?,
      sleep: sleep,
      steps: data['steps'] as int?,
      stress: data['stress'] as int?,
      tzAtWake: data['tzAtWake'] as String?,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as dynamic).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{};
    if (moodScore != null) map['moodScore'] = moodScore;
    if (sleep != null) map['sleep'] = sleep!.toMap();
    if (steps != null) map['steps'] = steps;
    if (stress != null) map['stress'] = stress;
    if (tzAtWake != null) map['tzAtWake'] = tzAtWake;
    return map;
  }
}

class SleepData {
  final String? bedTime; // HH:mm
  final String? wakeTime; // HH:mm
  final double? durationHours; // 自動計算
  final String source; // 'manual' or 'auto'

  SleepData({
    this.bedTime,
    this.wakeTime,
    this.durationHours,
    this.source = 'manual',
  });

  factory SleepData.fromMap(Map<String, dynamic> map) {
    return SleepData(
      bedTime: map['bedTime'] as String?,
      wakeTime: map['wakeTime'] as String?,
      durationHours: (map['durationHours'] as num?)?.toDouble(),
      source: (map['source'] as String?) ?? 'manual',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (bedTime != null) 'bedTime': bedTime,
      if (wakeTime != null) 'wakeTime': wakeTime,
      if (durationHours != null) 'durationHours': durationHours,
      'source': source,
    };
  }

  /// 就寝・起床時刻から睡眠時間を計算
  static double? calcDuration(String? bedTime, String? wakeTime) {
    if (bedTime == null || wakeTime == null) return null;
    try {
      final bedParts = bedTime.split(':');
      final wakeParts = wakeTime.split(':');
      final bedMinutes = int.parse(bedParts[0]) * 60 + int.parse(bedParts[1]);
      final wakeMinutes =
          int.parse(wakeParts[0]) * 60 + int.parse(wakeParts[1]);

      int diff = wakeMinutes - bedMinutes;
      if (diff <= 0) diff += 24 * 60; // 日をまたぐ場合

      return diff / 60.0;
    } catch (_) {
      return null;
    }
  }
}
