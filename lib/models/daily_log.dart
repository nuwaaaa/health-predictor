/// 日次ログのデータクラス
/// Firestore: users/{uid}/daily/{dateKey}
class DailyLog {
  final String dateKey; // YYYY-MM-DD（最長睡眠ブロックの起床日ベース）
  final int? moodScore; // 1〜5
  final SleepData? sleep;
  final List<SleepSegment> sleepSegments;
  final SleepSummary? sleepSummary;
  final int? steps;
  final String? stepsSource; // 'manual' or 'auto'
  final int? stress; // 1〜5（任意）
  final String? tzAtWake; // 例: Asia/Tokyo
  final DateTime? updatedAt;

  DailyLog({
    required this.dateKey,
    this.moodScore,
    this.sleep,
    this.sleepSegments = const [],
    this.sleepSummary,
    this.steps,
    this.stepsSource,
    this.stress,
    this.tzAtWake,
    this.updatedAt,
  });

  factory DailyLog.fromFirestore(String docId, Map<String, dynamic> data) {
    SleepData? sleep;
    if (data['sleep'] is Map<String, dynamic>) {
      sleep = SleepData.fromMap(data['sleep'] as Map<String, dynamic>);
    }

    final segments = <SleepSegment>[];
    if (data['sleepSegments'] is List) {
      for (final s in data['sleepSegments'] as List) {
        if (s is Map<String, dynamic>) {
          segments.add(SleepSegment.fromMap(s));
        }
      }
    }

    SleepSummary? summary;
    if (data['sleepSummary'] is Map<String, dynamic>) {
      summary =
          SleepSummary.fromMap(data['sleepSummary'] as Map<String, dynamic>);
    }

    return DailyLog(
      dateKey: docId,
      moodScore: data['moodScore'] as int?,
      sleep: sleep,
      sleepSegments: segments,
      sleepSummary: summary,
      steps: data['steps'] as int?,
      stepsSource: data['stepsSource'] as String?,
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
    if (sleepSegments.isNotEmpty) {
      map['sleepSegments'] = sleepSegments.map((s) => s.toMap()).toList();
    }
    if (sleepSummary != null) map['sleepSummary'] = sleepSummary!.toMap();
    if (steps != null) map['steps'] = steps;
    if (stepsSource != null) map['stepsSource'] = stepsSource;
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

/// 個別の睡眠セグメント（主睡眠・仮眠を区別しない生データ）
class SleepSegment {
  final String start; // ISO 8601 ローカル時刻 "2026-03-23T23:30:00"
  final String end;   // ISO 8601 ローカル時刻 "2026-03-24T07:00:00"
  final int minutes;
  final String source; // 'manual' or 'auto'

  SleepSegment({
    required this.start,
    required this.end,
    required this.minutes,
    this.source = 'manual',
  });

  factory SleepSegment.fromMap(Map<String, dynamic> map) {
    return SleepSegment(
      start: map['start'] as String? ?? '',
      end: map['end'] as String? ?? '',
      minutes: (map['minutes'] as num?)?.toInt() ?? 0,
      source: (map['source'] as String?) ?? 'manual',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'start': start,
      'end': end,
      'minutes': minutes,
      'source': source,
    };
  }

  /// セグメントの開始時刻を "HH:mm" 形式で返す
  String get startTime {
    try {
      final dt = DateTime.parse(start);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--';
    }
  }

  /// セグメントの終了時刻を "HH:mm" 形式で返す
  String get endTime {
    try {
      final dt = DateTime.parse(end);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--';
    }
  }
}

/// 睡眠セグメントの集約データ（派生概念）
class SleepSummary {
  final int totalSleepMin;
  final int longestBlockMin;
  final String? longestBlockStart; // "HH:mm"
  final String? longestBlockEnd;   // "HH:mm"
  final int segmentCount;
  final int napTotalMin;

  SleepSummary({
    required this.totalSleepMin,
    required this.longestBlockMin,
    this.longestBlockStart,
    this.longestBlockEnd,
    required this.segmentCount,
    required this.napTotalMin,
  });

  double get totalSleepHours => totalSleepMin / 60.0;
  double get longestBlockHours => longestBlockMin / 60.0;
  double get napTotalHours => napTotalMin / 60.0;

  factory SleepSummary.fromMap(Map<String, dynamic> map) {
    return SleepSummary(
      totalSleepMin: (map['totalSleepMin'] as num?)?.toInt() ?? 0,
      longestBlockMin: (map['longestBlockMin'] as num?)?.toInt() ?? 0,
      longestBlockStart: map['longestBlockStart'] as String?,
      longestBlockEnd: map['longestBlockEnd'] as String?,
      segmentCount: (map['segmentCount'] as num?)?.toInt() ?? 1,
      napTotalMin: (map['napTotalMin'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalSleepMin': totalSleepMin,
      'longestBlockMin': longestBlockMin,
      if (longestBlockStart != null) 'longestBlockStart': longestBlockStart,
      if (longestBlockEnd != null) 'longestBlockEnd': longestBlockEnd,
      'segmentCount': segmentCount,
      'napTotalMin': napTotalMin,
    };
  }

  /// 睡眠セグメントのリストからサマリーを計算する。
  /// ギャップ30分未満のセグメントを結合してブロックを形成し、
  /// 最長ブロック=主睡眠、それ以外=仮眠として集約する。
  static SleepSummary fromSegments(List<SleepSegment> segments) {
    if (segments.isEmpty) {
      return SleepSummary(
        totalSleepMin: 0,
        longestBlockMin: 0,
        segmentCount: 0,
        napTotalMin: 0,
      );
    }

    // セグメントを開始時刻でソート
    final sorted = List<SleepSegment>.from(segments)
      ..sort((a, b) => a.start.compareTo(b.start));

    // ギャップ30分未満のセグメントを結合してブロックを形成
    final blocks = <_SleepBlock>[];
    var currentStart = sorted.first.start;
    var currentEnd = sorted.first.end;
    var currentMin = sorted.first.minutes;

    for (int i = 1; i < sorted.length; i++) {
      final seg = sorted[i];
      try {
        final prevEnd = DateTime.parse(currentEnd);
        final nextStart = DateTime.parse(seg.start);
        final gapMinutes = nextStart.difference(prevEnd).inMinutes;

        if (gapMinutes < 30) {
          // ギャップ30分未満→結合（実際の睡眠時間のみ加算、ギャップ分は含めない）
          currentEnd = seg.end;
          currentMin += seg.minutes;
        } else {
          // 新しいブロック
          blocks.add(_SleepBlock(start: currentStart, end: currentEnd, minutes: currentMin));
          currentStart = seg.start;
          currentEnd = seg.end;
          currentMin = seg.minutes;
        }
      } catch (_) {
        blocks.add(_SleepBlock(start: currentStart, end: currentEnd, minutes: currentMin));
        currentStart = seg.start;
        currentEnd = seg.end;
        currentMin = seg.minutes;
      }
    }
    blocks.add(_SleepBlock(start: currentStart, end: currentEnd, minutes: currentMin));

    // 最長ブロックを特定
    blocks.sort((a, b) => b.minutes.compareTo(a.minutes));
    final longest = blocks.first;

    final totalMin = blocks.fold<int>(0, (sum, b) => sum + b.minutes);
    final napMin = totalMin - longest.minutes;

    // 最長ブロックの開始・終了時刻を "HH:mm" 形式で取得
    String? startHhmm;
    String? endHhmm;
    try {
      final s = DateTime.parse(longest.start);
      startHhmm = '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';
      final e = DateTime.parse(longest.end);
      endHhmm = '${e.hour.toString().padLeft(2, '0')}:${e.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    return SleepSummary(
      totalSleepMin: totalMin,
      longestBlockMin: longest.minutes,
      longestBlockStart: startHhmm,
      longestBlockEnd: endHhmm,
      segmentCount: blocks.length,
      napTotalMin: napMin,
    );
  }
}

class _SleepBlock {
  final String start;
  final String end;
  final int minutes;
  _SleepBlock({required this.start, required this.end, required this.minutes});
}
