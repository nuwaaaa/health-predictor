import 'package:shared_preferences/shared_preferences.dart';

/// アプリバージョン管理とデータマイグレーション基盤
///
/// スキーマ変更時にマイグレーション関数を [_migrations] に追加する。
/// アプリ起動時に [runMigrations] を呼び出す。
class MigrationService {
  static const _key = 'app_schema_version';

  /// 現在のスキーマバージョン（変更のたびにインクリメント）
  static const currentVersion = 1;

  /// バージョンごとのマイグレーション関数
  /// キー: マイグレーション先のバージョン番号
  static final Map<int, Future<void> Function()> _migrations = {
    // 例: 2: () async { /* v1→v2 のマイグレーション */ },
  };

  /// 必要なマイグレーションを順番に実行する
  static Future<void> runMigrations() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt(_key) ?? 0;

    if (storedVersion >= currentVersion) return;

    for (int v = storedVersion + 1; v <= currentVersion; v++) {
      final migration = _migrations[v];
      if (migration != null) {
        await migration();
      }
    }

    await prefs.setInt(_key, currentVersion);
  }
}
