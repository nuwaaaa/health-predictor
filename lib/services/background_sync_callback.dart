import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workmanager/workmanager.dart';
import '../firebase_options.dart';
import 'health_sync_service.dart';

/// workmanager のバックグラウンドタスク名
const healthSyncTaskName = 'healthDataSync';

/// workmanager の一意タスクID
const healthSyncTaskId = 'health-sync-periodic';

/// workmanager が呼び出すトップレベルコールバック。
/// バックグラウンド isolate で実行されるため、Flutter Engine の
/// 初期化とプラグイン登録が自動的に行われる。
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      // Firebase を初期化（バックグラウンド isolate では未初期化のため）
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseFirestore.instance.settings =
          const Settings(persistenceEnabled: true);

      // 認証状態を復元して uid を取得
      final user = await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((u) => u != null)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);

      if (user == null) {
        // 未認証 — スキップ（クラッシュさせない）
        return true;
      }

      final syncService = HealthSyncService();
      await syncService.syncAll(uid: user.uid, isBackground: true);

      return true;
    } catch (e) {
      // バックグラウンドタスクが例外で終了すると OS がペナルティを課すため、
      // エラーを握りつぶして true を返す
      return true;
    }
  });
}
