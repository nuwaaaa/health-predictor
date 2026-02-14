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
    try {
      final results = await Future.wait([
        _service.getTodayLog(),
        _service.getModelStatus(),
        _service.getLastNDays(7),
        _service.getTodayPrediction(),
      ]);
      setState(() {
        _todayLog = results[0] as DailyLog?;
        _status = results[1] as ModelStatus;
        _last7 = results[2] as List<DailyLog>;
        _prediction = results[3] as Prediction?;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('読み込み失敗: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
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
