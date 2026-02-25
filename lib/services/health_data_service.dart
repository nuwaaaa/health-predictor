import 'package:health/health.dart';

/// HealthKit (iOS) / Health Connect (Android) からデータを取得するサービス
class HealthDataService {
  final Health _health = Health();

  /// 必要な権限の種類
  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_IN_BED,
  ];

  static final _permissions = _types.map((_) => HealthDataAccess.READ).toList();

  /// Health Connect / HealthKit のインストール確認 + SDK 利用可否
  Future<bool> isAvailable() async {
    final status = await Health().getHealthConnectSdkStatus();
    // iOS は常に true（HealthKit はシステム組み込み）
    // Android は Health Connect がインストール済みなら利用可能
    if (status == HealthConnectSdkStatus.sdkUnavailable) {
      return false;
    }
    return true;
  }

  /// 権限をリクエスト（初回のみダイアログが表示される）
  Future<bool> requestPermissions() async {
    try {
      return await _health.requestAuthorization(
        _types,
        permissions: _permissions,
      );
    } catch (_) {
      return false;
    }
  }

  /// 今日の歩数を取得（0:00〜現在）
  Future<int?> fetchTodaySteps() async {
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(midnight, now);
      return steps;
    } catch (_) {
      return null;
    }
  }

  /// 昨晩の睡眠データを取得
  /// 戻り値: {bedTime: "HH:mm", wakeTime: "HH:mm", durationHours: double} or null
  Future<Map<String, dynamic>?> fetchLastNightSleep() async {
    try {
      final now = DateTime.now();
      // 昨日の18:00〜今日の12:00の範囲で睡眠を検索
      final start = DateTime(now.year, now.month, now.day - 1, 18, 0);
      final end = DateTime(now.year, now.month, now.day, 12, 0);

      final sessions = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_IN_BED],
        startTime: start,
        endTime: end,
      );

      if (sessions.isEmpty) return null;

      // 最も早い開始時刻と最も遅い終了時刻を取得
      DateTime? earliest;
      DateTime? latest;

      for (final point in sessions) {
        if (earliest == null || point.dateFrom.isBefore(earliest)) {
          earliest = point.dateFrom;
        }
        if (latest == null || point.dateTo.isAfter(latest)) {
          latest = point.dateTo;
        }
      }

      if (earliest == null || latest == null) return null;

      final bedTime =
          '${earliest.hour.toString().padLeft(2, '0')}:${earliest.minute.toString().padLeft(2, '0')}';
      final wakeTime =
          '${latest.hour.toString().padLeft(2, '0')}:${latest.minute.toString().padLeft(2, '0')}';
      final durationHours =
          latest.difference(earliest).inMinutes / 60.0;

      if (durationHours <= 0 || durationHours > 24) return null;

      return {
        'bedTime': bedTime,
        'wakeTime': wakeTime,
        'durationHours':
            (durationHours * 10).roundToDouble() / 10, // 小数1桁
      };
    } catch (_) {
      return null;
    }
  }
}
