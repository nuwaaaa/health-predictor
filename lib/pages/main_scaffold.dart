import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_log.dart';
import '../models/model_status.dart';
import '../models/prediction.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/health_sync_service.dart';
import '../services/tomorrow_predictor.dart';
import '../services/widget_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tech_background.dart';
import 'home_page.dart';
import 'data_page.dart';
import 'analysis_page.dart';
import 'settings_page.dart';

/// 4タブ Bottom Navigation のメインスキャフォールド
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => MainScaffoldState();
}

class MainScaffoldState extends State<MainScaffold> with WidgetsBindingObserver {
  final _authService = AuthService();
  late final FirestoreService _service;

  int _currentIndex = 0;
  bool _loading = true;

  DailyLog? _todayLog;
  ModelStatus _status = ModelStatus();
  Prediction? _prediction;
  Prediction? _tomorrowPrediction;
  bool _isFallbackPrediction = false;
  List<DailyLog> _recentLogs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final uid = _authService.uid;
    if (uid == null) return;
    _service = FirestoreService(uid: uid);
    _loadAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading) {
      _autoSyncAndReload();
    }
  }

  /// アプリ復帰時にヘルスデータを自動同期してからデータを再読み込み
  Future<void> _autoSyncAndReload() async {
    final uid = _authService.uid;
    if (uid != null) {
      final syncService = HealthSyncService();
      await syncService.syncAll(uid: uid, isBackground: false);
    }
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final errors = <String>[];

    DailyLog? todayLog;
    ModelStatus status = ModelStatus();
    List<DailyLog> recentLogs = [];
    Prediction? prediction;
    bool isFallback = false;

    try {
      todayLog = await _service.getTodayLog();
    } catch (e) {
      errors.add('日次ログ: $e');
    }

    try {
      status = await _service.getModelStatus();
    } catch (e) {
      errors.add('モデル状態: $e');
    }

    try {
      recentLogs = await _service.getLastNDays(14);
    } catch (e) {
      errors.add('直近ログ: $e');
    }

    try {
      prediction = await _service.getTodayPrediction();
    } catch (e) {
      errors.add('今日の予測: $e');
    }

    if (prediction == null) {
      try {
        prediction = await _service.getLatestPrediction();
        isFallback = prediction != null;
      } catch (e) {
        errors.add('直近予測: $e');
      }
    }

    // 明日の予測をクライアント側で算出
    Prediction? tomorrowPrediction;
    if (status.modelParams != null &&
        status.modelType == 'logistic' &&
        todayLog?.moodScore != null) {
      tomorrowPrediction = TomorrowPredictor.predict(
        todayLog: todayLog!,
        recentLogs: recentLogs,
        modelParams: status.modelParams!,
        confidence: status.confidenceLevel,
      );
    }

    // ホーム画面ウィジェットを最新の予測で更新
    final widgetPrediction = prediction ?? tomorrowPrediction;
    if (widgetPrediction != null) {
      WidgetDataService.updateRiskWidget(
        riskPercent: widgetPrediction.riskPercent,
        riskLabel: widgetPrediction.riskLabel,
        confidence: widgetPrediction.confidence,
      );
    }

    if (!mounted) return;
    setState(() {
      _todayLog = todayLog;
      _status = status;
      _recentLogs = recentLogs;
      _prediction = prediction;
      _tomorrowPrediction = tomorrowPrediction;
      _isFallbackPrediction = isFallback;
      _loading = false;
    });

    // 同意情報がまだFirestoreに同期されていない場合に書き込む
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('consent_pending_sync') == true) {
      final version = prefs.getString('consent_version') ?? '1.0';
      final dateStr = prefs.getString('consent_date');
      final date = dateStr != null
          ? DateTime.tryParse(dateStr) ?? DateTime.now()
          : DateTime.now();
      try {
        await _service.recordConsent(version: version, date: date);
        await prefs.setBool('consent_pending_sync', false);
      } catch (_) {} // 失敗しても次回起動で再試行
    }

    if (errors.isNotEmpty) {
      debugPrint('読み込みエラー: $errors');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('データの読み込みに失敗しました')),
      );
    }
  }

  void switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  /// 直近7日分（チャート・DataPage用）
  List<DailyLog> get _last7 {
    if (_recentLogs.length <= 7) return _recentLogs;
    return _recentLogs.sublist(_recentLogs.length - 7);
  }

  @override
  Widget build(BuildContext context) {
    final c1 = techBgColor1(_prediction, _status);
    final c2 = techBgColor2(_prediction, _status);

    return Scaffold(
      body: Stack(
        children: [
          // 画面全体の背景装飾（回路 + ドット）
          Positioned.fill(
            child: TechBackground(color1: c1, color2: c2),
          ),
          // 各タブページ（Scaffold を透明化して背景を透過させる）
          Theme(
            data: Theme.of(context).copyWith(
              scaffoldBackgroundColor: Colors.transparent,
            ),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : IndexedStack(
                    index: _currentIndex,
                    children: [
                HomePage(
                  service: _service,
                  todayLog: _todayLog,
                  status: _status,
                  prediction: _prediction,
                  tomorrowPrediction: _tomorrowPrediction,
                  isFallbackPrediction: _isFallbackPrediction,
                  onReload: _loadAll,
                  onSwitchTab: switchTab,
                ),
                DataPage(
                  service: _service,
                  logs: _last7,
                  onReload: _loadAll,
                ),
                AnalysisPage(
                  service: _service,
                  logs: _last7,
                  prediction: _prediction,
                  tomorrowPrediction: _tomorrowPrediction,
                  isFallbackPrediction: _isFallbackPrediction,
                  status: _status,
                ),
                SettingsPage(
                  authService: _authService,
                  service: _service,
                  onReload: _loadAll,
                ),
                  ],
                ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.cardColor,
          border: Border(
            top: BorderSide(color: context.dividerColor, width: 0.5),
          ),
        ),
        child: NavigationBar(
          backgroundColor: context.cardColor,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.primaryTint,
          selectedIndex: _currentIndex,
          onDestinationSelected: switchTab,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: context.textSubColor),
              selectedIcon: const Icon(Icons.home, color: AppColors.primary),
              label: 'ホーム',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined, color: context.textSubColor),
              selectedIcon: const Icon(Icons.bar_chart, color: AppColors.primary),
              label: 'データ',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_outlined, color: context.textSubColor),
              selectedIcon: const Icon(Icons.search, color: AppColors.primary),
              label: '分析',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, color: context.textSubColor),
              selectedIcon: const Icon(Icons.settings, color: AppColors.primary),
              label: '設定',
            ),
          ],
        ),
      ),
    );
  }
}
