import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/daily_log.dart';
import '../models/model_status.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String uid;

  FirestoreService({required this.uid});

  // --- References ---

  DocumentReference get _userDoc => _db.collection('users').doc(uid);

  CollectionReference get _dailyCol => _userDoc.collection('daily');

  DocumentReference get _statusRef =>
      _userDoc.collection('model_status').doc('current');

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
    final snap = await _dailyCol
        .orderBy(FieldPath.documentId, descending: true)
        .limit(n)
        .get();

    final logs = snap.docs
        .map((d) =>
            DailyLog.fromFirestore(d.id, d.data() as Map<String, dynamic>))
        .where((log) => log.moodScore != null)
        .toList();

    return logs.reversed.toList(); // 古い→新しい
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

  /// 睡眠データを保存
  Future<void> saveSleep({
    required String bedTime,
    required String wakeTime,
    required double durationHours,
  }) async {
    final key = todayKey();
    await _dailyCol.doc(key).set({
      'sleep': {
        'bedTime': bedTime,
        'wakeTime': wakeTime,
        'durationHours': durationHours,
        'source': 'manual',
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 歩数を保存
  Future<void> saveSteps(int steps) async {
    final key = todayKey();
    await _dailyCol.doc(key).set({
      'steps': steps,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ストレスを保存
  Future<void> saveStress(int stress) async {
    final key = todayKey();
    await _dailyCol.doc(key).set({
      'stress': stress,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // --- テスト用 ---

  /// 直近7日分のテストデータを一括作成
  Future<void> seedTestData() async {
    final batch = _db.batch();
    final scores = [3, 4, 2, 5, 3, 4, 4];
    final sleepHours = [7.0, 6.5, 5.5, 8.0, 7.5, 6.0, 7.0];
    final stepsList = [8000, 6500, 3000, 10000, 7500, 5000, 9000];

    for (int i = 0; i < 7; i++) {
      final day = DateTime.now().subtract(Duration(days: 6 - i));
      final key = dateKey(day);
      final ref = _dailyCol.doc(key);

      batch.set(
        ref,
        {
          'moodScore': scores[i],
          'sleep': {
            'durationHours': sleepHours[i],
            'source': 'test',
          },
          'steps': stepsList[i],
          'tzAtWake': DateTime.now().timeZoneName,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    // model_status を更新
    final allDocs = await _dailyCol.get();
    final count = allDocs.docs
        .where((d) => (d.data() as Map<String, dynamic>)['moodScore'] is int)
        .length;

    await _statusRef.set({
      'daysCollected': count,
      'daysRequired': 14,
      'ready': count >= 14,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
