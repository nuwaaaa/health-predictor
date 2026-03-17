import 'dart:math';

import '../models/daily_log.dart';
import '../models/model_status.dart';
import '../models/prediction.dart';
import 'firestore_service.dart';

/// クライアント側ロジスティック回帰で「明日の不調リスク」を推論する。
///
/// バッチで学習したモデルの係数・スケーラーを使い、
/// ユーザーが入力した当日データから翌日の特徴量を構築して確率を算出する。
class TomorrowPredictor {
  /// 明日の不調リスクを予測する。
  ///
  /// [todayLog] 今日の日次ログ（体調スコア必須）
  /// [recentLogs] 直近14日分のログ（古→新、今日を含む）
  /// [modelParams] バッチで保存されたモデルパラメータ
  /// [confidence] 現在の信頼度レベル
  static Prediction? predict({
    required DailyLog todayLog,
    required List<DailyLog> recentLogs,
    required ModelParams modelParams,
    required String confidence,
  }) {
    if (todayLog.moodScore == null) return null;

    final featureCols = modelParams.featureColumns;
    final n = featureCols.length;

    // 特徴量を構築
    final featureMap = _buildFeatureMap(todayLog, recentLogs);
    if (featureMap == null) return null;

    // featureColumns の順序で配列化
    final features = featureCols.map((c) => featureMap[c] ?? 0.0).toList();

    // スケーリング
    final scaled = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      final s = modelParams.scalerScale[i];
      scaled[i] = s == 0 ? 0 : (features[i] - modelParams.scalerMean[i]) / s;
    }

    // ロジスティック回帰: p = sigmoid(b0 + Σ bi·xi)
    double logit = modelParams.intercept;
    for (int i = 0; i < n; i++) {
      logit += modelParams.coefficients[i] * scaled[i];
    }
    double probability = 1.0 / (1.0 + exp(-logit));
    probability = (probability * 10000).roundToDouble() / 10000;

    // 寄与度 (coef × scaled_feature) → sin/cosペア合算 → TOP3
    final rawContribs = <String, double>{};
    for (int i = 0; i < n; i++) {
      rawContribs[featureCols[i]] = modelParams.coefficients[i] * scaled[i];
    }
    final allContribs = _mergeSinCosPairs(rawContribs);

    // 明日の日付キー
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final dateKey = FirestoreService.dateKey(tomorrow);

    return Prediction(
      dateKey: dateKey,
      pToday: probability,
      confidence: confidence,
      contributions: allContribs.take(3).toList(),
      provisional: true,
      source: 'on_demand_input',
    );
  }

  /// 明日 (D+1) の予測に必要な17特徴量をマップで構築する。
  ///
  /// 「data(D) → risk(D+1)」の関係:
  ///   mood_lag1  = mood(D)       ... 今日の体調
  ///   steps      = steps(D)      ... 今日の歩数
  ///   stress     = stress(D)     ... 今日のストレス
  ///   sleep      = sleep(D+1)    ... 明晩の睡眠（未知→平均で補完）
  static Map<String, double>? _buildFeatureMap(
    DailyLog today,
    List<DailyLog> recentLogs,
  ) {
    if (today.moodScore == null) return null;

    // 直近の体調スコアを収集（今日を含む）
    final moodScores = <double>[];
    for (final log in recentLogs) {
      if (log.moodScore != null) {
        moodScores.add(log.moodScore!.toDouble());
      }
    }
    if (moodScores.isEmpty) return null;

    // --- 曜日特徴量（sin/cosエンコーディング）---
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final dow = (tomorrow.weekday - 1).toDouble(); // 0=Mon..6=Sun
    final daySin = sin(2 * pi * dow / 7);
    final dayCos = cos(2 * pi * dow / 7);
    final isWeekend =
        (tomorrow.weekday == 6 || tomorrow.weekday == 7) ? 1.0 : 0.0;

    // --- 体調特徴量（mood(D) を "lag1" として使用）---
    final moodLag1 = today.moodScore!.toDouble();
    final moodMa3 = _rollingMean(moodScores, 3);
    final moodMa7 = _rollingMean(moodScores, 7);

    double moodDelta1 = 0;
    if (moodScores.length >= 2) {
      moodDelta1 = moodScores.last - moodScores[moodScores.length - 2];
    }

    double moodDev14 = 0;
    if (moodScores.length >= 7) {
      final ma14 = _rollingMean(moodScores, 14);
      moodDev14 = moodScores.last - ma14;
    }

    // --- 睡眠特徴量（D+1 の睡眠は未知→平均で補完）---
    final sleepValues = <double>[];
    for (final log in recentLogs) {
      if (log.sleep?.durationHours != null) {
        sleepValues.add(log.sleep!.durationHours!);
      }
    }
    final sleepFilled =
        sleepValues.isNotEmpty ? _rollingMean(sleepValues, 7) : 0.0;
    const sleepDev = 0.0; // 平均で補完→偏差≈0

    // --- 就寝・起床時刻の周期特徴量（D+1 は未知→過去平均で補完）---
    final bedMinutesList = <double>[];
    final wakeMinutesList = <double>[];
    for (final log in recentLogs) {
      if (log.sleep?.bedTime != null) {
        var m = _parseTimeToMinutes(log.sleep!.bedTime!);
        if (m < 720) m += 1440; // 正午未満をシフトして平均を正しく計算
        bedMinutesList.add(m);
      }
      if (log.sleep?.wakeTime != null) {
        wakeMinutesList.add(_parseTimeToMinutes(log.sleep!.wakeTime!));
      }
    }
    final bedFilled = bedMinutesList.isNotEmpty
        ? _rollingMean(bedMinutesList, 7)
        : 1410.0; // デフォルト ~23:30
    final wakeFilled = wakeMinutesList.isNotEmpty
        ? _rollingMean(wakeMinutesList, 7)
        : 420.0; // デフォルト ~07:00

    final bedSin = sin(2 * pi * bedFilled / 1440);
    final bedCos = cos(2 * pi * bedFilled / 1440);
    final wakeSin = sin(2 * pi * wakeFilled / 1440);
    final wakeCos = cos(2 * pi * wakeFilled / 1440);

    // --- 歩数特徴量（steps(D) = 今日の歩数）---
    final stepsHistory = <double>[];
    for (final log in recentLogs) {
      if (log.steps != null) stepsHistory.add(log.steps!.toDouble());
    }
    double stepsFilled;
    if (today.steps != null) {
      stepsFilled = today.steps!.toDouble();
    } else {
      stepsFilled =
          stepsHistory.isNotEmpty ? _rollingMean(stepsHistory, 7) : 0.0;
    }
    double stepsDev = 0;
    if (stepsHistory.isNotEmpty) {
      stepsDev = stepsFilled - _rollingMean(stepsHistory, 7);
    }

    // --- ストレス特徴量（stress(D) = 今日のストレス）---
    final stressHistory = <double>[];
    for (final log in recentLogs) {
      if (log.stress != null) stressHistory.add(log.stress!.toDouble());
    }
    double stressFilled;
    if (today.stress != null) {
      stressFilled = today.stress!.toDouble();
    } else {
      stressFilled =
          stressHistory.isNotEmpty ? _rollingMean(stressHistory, 7) : 0.0;
    }

    return {
      'day_sin': daySin,
      'day_cos': dayCos,
      'is_weekend': isWeekend,
      'mood_lag1': moodLag1,
      'mood_ma3': moodMa3,
      'mood_ma7': moodMa7,
      'mood_delta1': moodDelta1,
      'mood_dev14': moodDev14,
      'sleep_hours_filled': sleepFilled,
      'sleep_dev': sleepDev,
      'bed_sin': bedSin,
      'bed_cos': bedCos,
      'wake_sin': wakeSin,
      'wake_cos': wakeCos,
      'steps_filled': stepsFilled,
      'steps_dev': stepsDev,
      'stress_filled': stressFilled,
    };
  }

  /// sin/cos ペアの寄与度を単純加算で合算する。
  /// LR の coef×feature は log-odds 空間で加法的なので単純和が正しい。
  static const _sinCosPairs = {
    'day_sin': 'day_cos',
    'bed_sin': 'bed_cos',
    'wake_sin': 'wake_cos',
  };

  static List<FeatureContribution> _mergeSinCosPairs(
      Map<String, double> contribs) {
    final cosKeys = _sinCosPairs.values.toSet();
    final merged = <FeatureContribution>[];
    for (final entry in contribs.entries) {
      if (cosKeys.contains(entry.key)) continue; // cos 側はスキップ
      if (_sinCosPairs.containsKey(entry.key)) {
        final vSin = entry.value;
        final vCos = contribs[_sinCosPairs[entry.key]!] ?? 0.0;
        merged.add(FeatureContribution(feature: entry.key, value: vSin + vCos));
      } else {
        merged.add(FeatureContribution(feature: entry.key, value: entry.value));
      }
    }
    merged.sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    return merged;
  }

  /// "HH:mm" 文字列を分(double)に変換する。
  static double _parseTimeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60.0 + int.parse(parts[1]);
  }

  /// 直近 [window] 件の平均を計算（min_periods=1 相当）。
  static double _rollingMean(List<double> values, int window) {
    if (values.isEmpty) return 0;
    final start = max(0, values.length - window);
    final slice = values.sublist(start);
    return slice.reduce((a, b) => a + b) / slice.length;
  }
}
