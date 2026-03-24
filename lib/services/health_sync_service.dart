import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_log.dart';
import 'firestore_service.dart';
import 'health_data_service.dart';

/// HealthKit / Health Connect からデータを取得し Firestore に保存する同期サービス。
/// フォアグラウンド（アプリ復帰時）とバックグラウンド（workmanager）の
/// 両方から呼び出し可能。Widget に依存しない。
class HealthSyncService {
  static const _lastSyncKey = 'lastSyncTimestamp';
  static const _autoSyncEnabledKey = 'autoSyncEnabled';

  /// フォアグラウンド同期の最小間隔（秒）
  static const _foregroundThrottleSec = 15 * 60; // 15分

  final HealthDataService _healthService = HealthDataService();

  /// 自動同期が有効かどうかを取得
  static Future<bool> isAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSyncEnabledKey) ?? true; // デフォルト ON
  }

  /// 自動同期の有効/無効を設定
  static Future<void> setAutoSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncEnabledKey, enabled);
  }

  /// 歩数・睡眠データを HealthKit/Health Connect から取得し Firestore に保存する。
  ///
  /// [uid] Firebase Auth UID
  /// [isBackground] バックグラウンド実行時は true（スロットリングをスキップ）
  ///
  /// 戻り値: 同期結果
  Future<SyncResult> syncAll({
    required String uid,
    bool isBackground = false,
  }) async {
    try {
      // 自動同期が無効なら skip
      if (!await isAutoSyncEnabled()) {
        return SyncResult.skipped;
      }

      // フォアグラウンド時はスロットリング
      if (!isBackground) {
        final prefs = await SharedPreferences.getInstance();
        final lastSync = prefs.getInt(_lastSyncKey) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (now - lastSync < _foregroundThrottleSec) {
          return SyncResult.skipped;
        }
      }

      // 権限チェック（バックグラウンドではダイアログが出せないので request ではなく暗黙チェック）
      final hasPermission = await _healthService.requestPermissions();
      if (!hasPermission) {
        return SyncResult.noPermission;
      }

      final service = FirestoreService(uid: uid);

      // 歩数と睡眠を並行取得
      final results = await Future.wait([
        _healthService.fetchTodaySteps(),
        _healthService.fetchSleepSegments(),
      ]);

      final steps = results[0] as int?;
      final segments = results[1] as List<SleepSegment>;

      bool synced = false;

      // 歩数を保存
      if (steps != null && steps > 0) {
        await service.saveSteps(steps, source: 'auto');
        synced = true;
      }

      // 睡眠セグメントを保存
      if (segments.isNotEmpty) {
        await service.saveSleepSegments(segments: segments);
        synced = true;
      }

      // 最終同期時刻を記録
      if (synced) {
        final prefs = await SharedPreferences.getInstance();
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await prefs.setInt(_lastSyncKey, now);
      }

      return synced ? SyncResult.success : SyncResult.skipped;
    } catch (e) {
      debugPrint('HealthSyncService.syncAll エラー: $e');
      return SyncResult.error;
    }
  }
}

enum SyncResult {
  success,
  skipped,
  noPermission,
  noAuth,
  error,
}
