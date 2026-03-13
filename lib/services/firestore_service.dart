import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/daily_log.dart';
import '../models/model_status.dart';
import '../models/prediction.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String uid;

  FirestoreService({required this.uid});

  // --- References ---

  DocumentReference get _userDoc => _db.collection('users').doc(uid);

  CollectionReference get _dailyCol => _userDoc.collection('daily');

  DocumentReference get _statusRef =>
      _userDoc.collection('model_status').doc('current');

  CollectionReference get _predictionsCol =>
      _userDoc.collection('predictions');

  // --- Date Key ---

  static String dateKey(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  static String todayKey() => dateKey(DateTime.now());

  // --- Read ---

  /// 今日の日次ログを取得
  Future<DailyLog?> getTodayLog() async {
    final key = todayKey();
    final doc = await _dailyCol.doc(key).get();
    if (!doc.exists) return null;
    return DailyLog.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
  }

  /// 直近N日分のログを取得（古い→新しい順）
  Future<List<DailyLog>> getLastNDays(int n) async {
    // 日付範囲で取得（カスタムインデックス不要）
    final startKey = dateKey(DateTime.now().subtract(Duration(days: n)));
    final snap = await _dailyCol
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startKey)
        .get();

    final logs = snap.docs
        .map((d) =>
            DailyLog.fromFirestore(d.id, d.data() as Map<String, dynamic>))
        .where((log) => log.moodScore != null)
        .toList();

    // ドキュメントIDで昇順ソート（古い→新しい）
    logs.sort((a, b) => a.dateKey.compareTo(b.dateKey));
    return logs;
  }

  /// model_status を取得
  Future<ModelStatus> getModelStatus() async {
    final doc = await _statusRef.get();
    if (!doc.exists) return ModelStatus();
    return ModelStatus.fromFirestore(doc.data() as Map<String, dynamic>);
  }

  // --- Write ---

  /// 体調スコアを保存（トランザクションで daysCollected も更新）
  Future<void> saveMoodScore(int score) async {
    final key = todayKey();
    final dailyRef = _dailyCol.doc(key);
    final tz = DateTime.now().timeZoneName;

    await _db.runTransaction((tx) async {
      final dailySnap = await tx.get(dailyRef);
      final isFirstToday = !dailySnap.exists;

      final statusSnap = await tx.get(_statusRef);
      final statusData = statusSnap.data() as Map<String, dynamic>? ?? {};
      final currentDays = (statusData['daysCollected'] as int?) ?? 0;
      final required = (statusData['daysRequired'] as int?) ?? 14;
      final nextDays = isFirstToday ? currentDays + 1 : currentDays;

      // daily 保存
      tx.set(
        dailyRef,
        {
          'moodScore': score,
          'tzAtWake': tz,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // model_status 更新
      tx.set(
        _statusRef,
        {
          'daysCollected': nextDays,
          'daysRequired': required,
          'ready': nextDays >= required,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  /// 指定日のログを取得
  Future<DailyLog?> getLogForDate(String dateKey) async {
    final doc = await _dailyCol.doc(dateKey).get();
    if (!doc.exists) return null;
    return DailyLog.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
  }

  /// 睡眠データを保存
  Future<void> saveSleep({
    required String bedTime,
    required String wakeTime,
    required double durationHours,
    String source = 'manual',
    String? dateKeyOverride,
  }) async {
    final key = dateKeyOverride ?? todayKey();
    await _dailyCol.doc(key).set({
      'sleep': {
        'bedTime': bedTime,
        'wakeTime': wakeTime,
        'durationHours': durationHours,
        'source': source,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 歩数を保存
  Future<void> saveSteps(int steps, {String source = 'manual', String? dateKeyOverride}) async {
    final key = dateKeyOverride ?? todayKey();
    await _dailyCol.doc(key).set({
      'steps': steps,
      'stepsSource': source,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ストレスを保存
  Future<void> saveStress(int stress, {String? dateKeyOverride}) async {
    final key = dateKeyOverride ?? todayKey();
    await _dailyCol.doc(key).set({
      'stress': stress,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 体調スコアを指定日に保存（過去データ編集用、daysCollected更新なし）
  Future<void> saveMoodScoreForDate(String dateKey, int score) async {
    await _dailyCol.doc(dateKey).set({
      'moodScore': score,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // --- Predictions ---

  /// 今日の予測結果を取得
  Future<Prediction?> getTodayPrediction() async {
    final key = todayKey();
    final doc = await _predictionsCol.doc(key).get();
    if (!doc.exists) return null;
    return Prediction.fromFirestore(
        doc.id, doc.data() as Map<String, dynamic>);
  }

  /// 直近の予測結果を取得（今日の予測がない場合のフォールバック用）
  Future<Prediction?> getLatestPrediction() async {
    // 直近30日分を取得し、最新のものを返す（カスタムインデックス不要）
    final startKey = dateKey(DateTime.now().subtract(const Duration(days: 30)));
    final snap = await _predictionsCol
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startKey)
        .get();
    if (snap.docs.isEmpty) return null;
    // 最後のドキュメント（最新日付）を取得
    final docs = snap.docs.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final doc = docs.last;
    return Prediction.fromFirestore(
        doc.id, doc.data() as Map<String, dynamic>);
  }

  // --- Feedback ---

  /// 週次フィードバックを保存
  /// result: 'correct', 'incorrect', 'unknown'
  Future<void> saveWeeklyFeedback({
    required String weekKey,
    required String result,
  }) async {
    await _userDoc.collection('feedback').doc(weekKey).set({
      'result': result,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 直近のフィードバック済み週キーを取得（重複防止用）
  Future<String?> getLatestFeedbackWeek() async {
    // 全フィードバックを取得し、最新のものを返す（カスタムインデックス不要）
    final snap = await _userDoc
        .collection('feedback')
        .get();
    if (snap.docs.isEmpty) return null;
    final docs = snap.docs.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return docs.last.id;
  }

  // --- アカウント削除 ---

  /// ユーザーの全サブコレクションを削除
  /// TODO: 設計書 Section 15.2 に従い Cloud Functions (onDelete トリガー)
  ///       で predictions サブコレクションも自動削除する仕組みを追加する
  Future<void> deleteAllUserData() async {
    final deletable = ['daily', 'model_status', 'feedback', 'predictions', 'batch_logs'];
    for (final name in deletable) {
      final col = _userDoc.collection(name);
      final docs = await col.get();
      final batch = _db.batch();
      for (final doc in docs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    // ユーザードキュメント自体も削除
    await _userDoc.delete();
  }

  // --- テスト用 ---

  /// テストデータ + 今日の予測結果を一括作成
  ///
  /// [totalDays] で日数を指定可能（デフォルト100日）
  ///
  /// 体調パターン:
  ///   - ベースライン 3〜4 で推移
  ///   - 週末はやや回復傾向
  ///   - 2〜3週間に1回、2〜3日続く不調期（スコア1〜2）を挿入
  ///   - 睡眠不足の翌日は体調が下がりやすい
  Future<void> seedTestData({int totalDays = 100}) async {
    final rng = Random(42); // 再現性のためシード固定
    final now = DateTime.now();

    // --- 日次データ生成 ---
    final List<Map<String, dynamic>> dailyRows = [];
    final List<int> moodScores = [];

    // 不調期の開始日（0-indexed, 今日からの遡り日数）
    // totalDaysに応じてフィルタ
    final Set<int> sickDays = {};
    for (final start in [8, 25, 48, 67, 85]) {
      if (start >= totalDays) continue;
      final duration = 2 + rng.nextInt(2); // 2〜3日
      for (int d = 0; d < duration; d++) {
        sickDays.add(start + d);
      }
    }

    for (int i = 0; i < totalDays; i++) {
      final day = now.subtract(Duration(days: totalDays - 1 - i));
      final key = dateKey(day);
      final weekday = day.weekday; // 1=Mon, 7=Sun
      final isWeekend = weekday >= 6;

      // 体調スコア
      int mood;
      if (sickDays.contains(totalDays - 1 - i)) {
        mood = 1 + rng.nextInt(2); // 1〜2
      } else if (isWeekend) {
        mood = 3 + rng.nextInt(2); // 3〜4 (週末は安定)
        if (rng.nextDouble() < 0.3) mood = 5; // たまに絶好調
      } else {
        mood = 3 + rng.nextInt(2); // 3〜4
        if (rng.nextDouble() < 0.15) mood = 2; // たまに軽い不調
        if (rng.nextDouble() < 0.1) mood = 5;
      }
      mood = mood.clamp(1, 5);
      moodScores.add(mood);

      // 睡眠時間（体調に相関させる）
      double baseSleep = 6.5 + rng.nextDouble() * 2.0; // 6.5〜8.5h
      if (mood <= 2) baseSleep -= 1.0 + rng.nextDouble(); // 不調期は睡眠短い
      if (isWeekend) baseSleep += 0.5; // 週末は長め
      final sleepHours =
          (baseSleep * 10).roundToDouble() / 10; // 小数1桁

      // 歩数
      int steps;
      if (mood <= 2) {
        steps = 2000 + rng.nextInt(3000); // 不調期は少ない
      } else {
        steps = 5000 + rng.nextInt(8000);
      }

      // ストレス（任意なので20%は欠損）
      int? stress;
      if (rng.nextDouble() > 0.2) {
        if (mood <= 2) {
          stress = 3 + rng.nextInt(3); // 不調時は高ストレス
        } else {
          stress = 1 + rng.nextInt(3);
        }
        stress = stress.clamp(1, 5);
      }

      final row = <String, dynamic>{
        'key': key,
        'moodScore': mood,
        'sleep': {
          'durationHours': sleepHours,
          'source': 'test',
        },
        'steps': steps,
        'tzAtWake': now.timeZoneName,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (stress != null) row['stress'] = stress;

      dailyRows.add(row);
    }

    // Firestore batch は500操作制限があるので分割
    for (int start = 0; start < dailyRows.length; start += 400) {
      final batch = _db.batch();
      final end = (start + 400).clamp(0, dailyRows.length);
      for (int j = start; j < end; j++) {
        final row = dailyRows[j];
        final ref = _dailyCol.doc(row['key'] as String);
        final data = Map<String, dynamic>.from(row)..remove('key');
        batch.set(ref, data, SetOptions(merge: true));
      }
      await batch.commit();
    }

    // --- 不調カウント ---
    // 14日移動平均を計算して不調フラグを数える
    int unhealthyCount = 0;
    for (int i = 13; i < moodScores.length; i++) {
      final window = moodScores.sublist(i - 13, i + 1);
      final avg = window.reduce((a, b) => a + b) / window.length;
      if (moodScores[i] <= avg - 1) unhealthyCount++;
    }

    // --- 今日の予測結果を生成（14日以上の場合のみ） ---
    final bool isReady = totalDays >= 14;
    final bool is3dReady = totalDays >= 60 && unhealthyCount >= 10;

    // 信頼度: 日数に応じて変化
    String confidence;
    if (totalDays >= 60) {
      confidence = 'high';
    } else if (totalDays >= 30) {
      confidence = 'medium';
    } else {
      confidence = 'low';
    }

    if (isReady) {
      final recentN = moodScores.length >= 7 ? 7 : moodScores.length;
      final recent = moodScores.sublist(moodScores.length - recentN);
      final avgRecent = recent.reduce((a, b) => a + b) / recent.length;
      final todayMood = moodScores.last;

      // リスク確率（体調が低いほど高い）
      double pToday = ((4.0 - avgRecent) / 4.0).clamp(0.0, 1.0);
      if (todayMood <= 2) pToday = (pToday + 0.3).clamp(0.0, 0.95);
      pToday = (pToday * 100).roundToDouble() / 100;

      // --- contributions (要因TOP3) を計算 ---
      // 直近データから現実的な寄与度を生成
      final yesterdayMood = moodScores.length >= 2
          ? moodScores[moodScores.length - 2]
          : 3;
      final lastSleep =
          (dailyRows.last['sleep'] as Map<String, dynamic>)['durationHours']
              as double;
      final lastSteps = dailyRows.last['steps'] as int;

      // 寄与度: 正=リスク増加, 負=リスク低下
      final contributions = <Map<String, dynamic>>[
        {
          'feature': 'mood_lag1',
          'value': (3.0 - yesterdayMood) * 0.3, // 体調低い→正(リスク増)
        },
        {
          'feature': 'sleep_hours_filled',
          'value': (7.0 - lastSleep) * 0.2, // 睡眠短い→正(リスク増)
        },
        {
          'feature': 'steps_filled',
          'value': (6000 - lastSteps) / 10000.0, // 歩数少ない→正(リスク増)
        },
      ];
      // 絶対値でソート（影響が大きい順）
      contributions.sort((a, b) =>
          (b['value'] as double).abs().compareTo((a['value'] as double).abs()));

      // --- advices (改善アドバイス) を計算 ---
      // 好調日・不調日の統計から backend/advice.py と同等のロジック
      final advices = <Map<String, dynamic>>[];
      if (totalDays >= 14) {
        final meanMood =
            moodScores.reduce((a, b) => a + b) / moodScores.length;
        final goodRows = <Map<String, dynamic>>[];
        final badRows = <Map<String, dynamic>>[];
        for (int i = 0; i < dailyRows.length; i++) {
          if (moodScores[i] >= meanMood + 0.5) goodRows.add(dailyRows[i]);
          if (moodScores[i] <= meanMood - 0.5) badRows.add(dailyRows[i]);
        }

        if (goodRows.length >= 3 && badRows.length >= 3) {
          // 睡眠アドバイス
          double goodSleepSum = 0, badSleepSum = 0;
          for (final r in goodRows) {
            goodSleepSum +=
                (r['sleep'] as Map<String, dynamic>)['durationHours'] as double;
          }
          for (final r in badRows) {
            badSleepSum +=
                (r['sleep'] as Map<String, dynamic>)['durationHours'] as double;
          }
          final avgGoodSleep = goodSleepSum / goodRows.length;
          final avgBadSleep = badSleepSum / badRows.length;
          if (avgGoodSleep - avgBadSleep > 0.3) {
            final recHours = (avgGoodSleep * 10).roundToDouble() / 10;
            advices.add({
              'param': 'sleep',
              'message':
                  '$recHours時間の睡眠をとった翌日は体調が安定する傾向があります',
            });
          }

          // 歩数アドバイス
          double goodStepsSum = 0, badStepsSum = 0;
          for (final r in goodRows) {
            goodStepsSum += (r['steps'] as int).toDouble();
          }
          for (final r in badRows) {
            badStepsSum += (r['steps'] as int).toDouble();
          }
          final avgGoodSteps = goodStepsSum / goodRows.length;
          final avgBadSteps = badStepsSum / badRows.length;
          if (avgGoodSteps - avgBadSteps > 500) {
            final threshold =
                (avgGoodSteps / 1000).round() * 1000;
            advices.add({
              'param': 'steps',
              'message':
                  '$threshold歩以上の日は体調が安定する傾向があります',
            });
          }
        }
      }

      final predData = <String, dynamic>{
        'pToday': pToday,
        'confidence': confidence,
        'generatedAt': FieldValue.serverTimestamp(),
        'modelVersion': 'logistic_v1',
        'contributions': contributions,
        'advices': advices.length > 2 ? advices.sublist(0, 2) : advices,
      };

      // 3日リスクは条件を満たす場合のみ
      if (is3dReady) {
        double p3d = (pToday * 1.3 + 0.05).clamp(0.0, 0.95);
        p3d = (p3d * 100).roundToDouble() / 100;
        predData['p3d'] = p3d;
      }

      try {
        final todayPredRef = _predictionsCol.doc(todayKey());
        await todayPredRef.set(predData);
      } catch (e) {
        debugPrint('predictions 書き込み失敗: $e');
        rethrow;
      }
    }

    // --- model_status 更新 ---
    // 直近14日の平均と標準偏差から閾値を計算: max(mean14-1, mean14-std14)
    double? moodMean14;
    double? unhealthyThreshold;
    if (isReady && moodScores.length >= 14) {
      final last14 = moodScores.sublist(moodScores.length - 14);
      final mean14 = last14.reduce((a, b) => a + b) / last14.length;
      double sumSq = 0;
      for (final m in last14) {
        sumSq += (m - mean14) * (m - mean14);
      }
      final std14 = sqrt(sumSq / last14.length);
      moodMean14 = (mean14 * 100).roundToDouble() / 100;
      final thresholdA = mean14 - 1;
      final thresholdB = mean14 - std14;
      unhealthyThreshold =
          ((thresholdA > thresholdB ? thresholdA : thresholdB) * 100)
                  .roundToDouble() /
              100;
    }

    final statusData = <String, dynamic>{
      'daysCollected': totalDays,
      'daysRequired': 14,
      'ready': isReady,
      'unhealthyCount': unhealthyCount,
      'recentMissingRate': 0.0,
      'modelType': 'logistic',
      'confidenceLevel': confidence,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (moodMean14 != null) statusData['moodMean14'] = moodMean14;
    if (unhealthyThreshold != null) statusData['unhealthyThreshold'] = unhealthyThreshold;

    // テスト用ダミーモデルパラメータ（クライアント側推論で明日の予測を表示するため）
    if (isReady) {
      // 16特徴量分のダミー係数（体調・睡眠に正の寄与を設定）
      statusData['modelParams'] = {
        'coefficients': [
          0.05,  // day_sin
          0.03,  // day_cos
          -0.1,  // is_weekend
          0.4,   // mood_lag1
          0.3,   // mood_ma3
          0.2,   // mood_ma7
          0.15,  // mood_delta1
          0.1,   // mood_dev14
          -0.3,  // sleep_hours_filled
          0.1,   // sleep_missing
          -0.05, // sleep_dev
          -0.1,  // steps_filled
          0.05,  // steps_missing
          -0.05, // steps_dev
          0.2,   // stress_filled
          0.05,  // stress_missing
        ],
        'intercept': -0.5,
        'scalerMean': [
          0.0, 0.0, 0.29, 3.2, 3.2, 3.2, 0.0, 0.0,
          7.0, 0.1, 0.0, 6500.0, 0.1, 0.0, 2.5, 0.2,
        ],
        'scalerScale': [
          0.7, 0.7, 0.45, 1.0, 0.8, 0.6, 0.8, 0.5,
          1.2, 0.3, 0.8, 3000.0, 0.3, 2000.0, 1.0, 0.4,
        ],
        'featureColumns': [
          'day_sin', 'day_cos', 'is_weekend', 'mood_lag1', 'mood_ma3',
          'mood_ma7', 'mood_delta1', 'mood_dev14',
          'sleep_hours_filled', 'sleep_missing', 'sleep_dev',
          'steps_filled', 'steps_missing', 'steps_dev',
          'stress_filled', 'stress_missing',
        ],
      };
    }

    await _statusRef.set(statusData, SetOptions(merge: true));
  }
}
