import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../models/model_status.dart';
import '../models/prediction.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
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

class MainScaffoldState extends State<MainScaffold> {
  final _authService = AuthService();
  late final FirestoreService _service;

  int _currentIndex = 0;
  bool _loading = true;

  DailyLog? _todayLog;
  ModelStatus _status = ModelStatus();
  Prediction? _prediction;
  bool _isFallbackPrediction = false;
  List<DailyLog> _last7 = [];

  @override
  void initState() {
    super.initState();
    final uid = _authService.uid;
    if (uid == null) return;
    _service = FirestoreService(uid: uid);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final errors = <String>[];

    // 各クエリを個別にtry-catchして、1つの失敗で全体が止まるのを防ぐ
    DailyLog? todayLog;
    ModelStatus status = ModelStatus();
    List<DailyLog> last7 = [];
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
      last7 = await _service.getLastNDays(7);
    } catch (e) {
      errors.add('直近7日: $e');
    }

    try {
      prediction = await _service.getTodayPrediction();
    } catch (e) {
      errors.add('今日の予測: $e');
    }

    // 今日の予測がない場合、直近の予測をフォールバック表示
    if (prediction == null) {
      try {
        prediction = await _service.getLatestPrediction();
        isFallback = prediction != null;
      } catch (e) {
        errors.add('直近予測: $e');
      }
    }

    setState(() {
      _todayLog = todayLog;
      _status = status;
      _last7 = last7;
      _prediction = prediction;
      _isFallbackPrediction = isFallback;
    });

    if (errors.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('読み込み失敗: ${errors.first}')),
      );
    }

    setState(() => _loading = false);
  }

  /// タブ切替（外部から呼べるように公開）
  void switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _currentIndex,
              children: [
                HomePage(
                  service: _service,
                  todayLog: _todayLog,
                  status: _status,
                  prediction: _prediction,
                  isFallbackPrediction: _isFallbackPrediction,
                  last7: _last7,
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
                  prediction: _prediction,
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: switchTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'データ',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: '分析',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }
}
