import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Flutter アプリと iOS/Android ホーム画面ウィジェット間のデータ連携サービス。
/// App Groups (iOS) / SharedPreferences (Android) を介してデータを共有する。
class WidgetDataService {
  /// iOS App Group ID（Widget Extension と共有）
  static const appGroupId = 'group.health-predictor';

  /// ウィジェット名（iOS の Widget Extension のターゲット名と一致させる）
  static const _iOSWidgetName = 'RiskWidget';

  /// Android のウィジェットクラス名
  static const _androidWidgetName = 'RiskWidgetReceiver';

  /// 初期化（main.dart で呼び出す）
  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(appGroupId);
  }

  /// 予測結果でウィジェットを更新する
  ///
  /// [riskPercent] リスク確率のパーセント表示（例: "45%"）
  /// [riskLabel] リスクレベルのラベル（例: "やや注意"）
  /// [confidence] 信頼度（"low", "medium", "high"）
  static Future<void> updateRiskWidget({
    required String riskPercent,
    required String riskLabel,
    required String confidence,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('riskPercent', riskPercent);
      await HomeWidget.saveWidgetData<String>('riskLabel', riskLabel);
      await HomeWidget.saveWidgetData<String>('confidence', confidence);
      await HomeWidget.saveWidgetData<String>(
        'lastUpdate',
        DateTime.now().toIso8601String(),
      );

      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        iOSName: _iOSWidgetName,
      );
    } catch (e) {
      debugPrint('WidgetDataService: ウィジェット更新失敗: $e');
    }
  }

  /// ウィジェットをクリアする（ログアウト時など）
  static Future<void> clearWidget() async {
    try {
      await HomeWidget.saveWidgetData<String>('riskPercent', '--%');
      await HomeWidget.saveWidgetData<String>('riskLabel', '---');
      await HomeWidget.saveWidgetData<String>('confidence', '');
      await HomeWidget.saveWidgetData<String>('lastUpdate', '');

      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        iOSName: _iOSWidgetName,
      );
    } catch (e) {
      debugPrint('WidgetDataService: ウィジェットクリア失敗: $e');
    }
  }
}
