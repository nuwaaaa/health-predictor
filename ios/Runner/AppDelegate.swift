import Flutter
import UIKit
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // workmanager: バックグラウンド isolate でもプラグインを登録
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    // バックグラウンドフェッチの最小間隔を設定（OS が最終決定）
    UIApplication.shared.setMinimumBackgroundFetchInterval(
      TimeInterval(60 * 60) // 1時間
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
