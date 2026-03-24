import 'package:health/health.dart';
import '../models/daily_log.dart';

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

  /// 指定日の歩数を取得（0:00〜23:59）
  /// [date] を省略すると今日のデータを取得
  Future<int?> fetchTodaySteps({DateTime? date}) async {
    try {
      final target = date ?? DateTime.now();
      final start = DateTime(target.year, target.month, target.day);
      final end = date != null
          ? DateTime(target.year, target.month, target.day, 23, 59, 59)
          : DateTime.now();
      final steps = await _health.getTotalStepsInInterval(start, end);
      return steps;
    } catch (_) {
      return null;
    }
  }

  /// 全睡眠セグメントを取得（前日12:00〜当日23:59の36時間ウィンドウ）
  /// [date] を省略すると今日を基準にしたウィンドウで取得
  ///
  /// 戻り値: SleepSegment のリスト（セグメント単位、統合しない）
  /// 主睡眠・仮眠の区別はしない（集約は SleepSummary.fromSegments で行う）
  Future<List<SleepSegment>> fetchSleepSegments({DateTime? date}) async {
    try {
      final target = date ?? DateTime.now();
      // 36時間ウィンドウ: 前日12:00 〜 当日23:59
      final start = DateTime(target.year, target.month, target.day - 1, 12, 0);
      final end = DateTime(target.year, target.month, target.day, 23, 59);

      final sessions = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_IN_BED],
        startTime: start,
        endTime: end,
      );

      if (sessions.isEmpty) return [];

      // セグメントに変換（重複排除: start+end の組み合わせ）
      final seen = <String>{};
      final segments = <SleepSegment>[];

      for (final point in sessions) {
        final key = '${point.dateFrom.toIso8601String()}_${point.dateTo.toIso8601String()}';
        if (seen.contains(key)) continue;
        seen.add(key);

        final minutes = point.dateTo.difference(point.dateFrom).inMinutes;
        if (minutes <= 0) continue;

        segments.add(SleepSegment(
          start: point.dateFrom.toIso8601String(),
          end: point.dateTo.toIso8601String(),
          minutes: minutes,
          source: 'auto',
        ));
      }

      // 開始時刻でソート
      segments.sort((a, b) => a.start.compareTo(b.start));
      return segments;
    } catch (_) {
      return [];
    }
  }

  /// 後方互換: 昨晩の睡眠データを取得（既存コード用）
  /// 内部で fetchSleepSegments を呼び、最長ブロックを返す
  /// 戻り値: {bedTime: "HH:mm", wakeTime: "HH:mm", durationHours: double} or null
  Future<Map<String, dynamic>?> fetchLastNightSleep() async {
    final segments = await fetchSleepSegments();
    if (segments.isEmpty) return null;

    final summary = SleepSummary.fromSegments(segments);
    if (summary.longestBlockMin <= 0) return null;
    if (summary.longestBlockStart == null || summary.longestBlockEnd == null) {
      return null;
    }

    final durationHours = summary.longestBlockMin / 60.0;
    if (durationHours <= 0 || durationHours > 24) return null;

    return {
      'bedTime': summary.longestBlockStart,
      'wakeTime': summary.longestBlockEnd,
      'durationHours': (durationHours * 10).roundToDouble() / 10,
    };
  }
}
