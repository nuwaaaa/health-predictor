import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../models/prediction.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/chart_7days.dart';
import '../widgets/comparison_chart.dart';
import '../widgets/calendar_view.dart';
import '../widgets/sleep_pattern_chart.dart';
import '../widgets/prediction_accuracy_chart.dart';
import '../widgets/correlation_scatter.dart';
import 'daily_input_page.dart';

/// データタブ — Calm Blue デザイン
class DataPage extends StatefulWidget {
  final FirestoreService service;
  final List<DailyLog> logs;
  final Future<void> Function() onReload;

  const DataPage({
    super.key,
    required this.service,
    required this.logs,
    required this.onReload,
  });

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  int _periodDays = 7;
  List<DailyLog>? _allLogs;
  bool _loadingMore = false;
  List<Prediction>? _predictions;

  /// 表示用ログ: 全データ取得済みならそれを使い、未取得なら widget.logs
  List<DailyLog> get _displayLogs => _allLogs ?? widget.logs;

  @override
  void initState() {
    super.initState();
    _fetchPredictions();
  }

  @override
  void didUpdateWidget(covariant DataPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 親から新しい logs が来たらキャッシュをクリアして再取得
    if (oldWidget.logs != widget.logs) {
      _allLogs = null;
      _predictions = null;
      _fetchPredictions();
      // 7日以外の期間が選択中なら全データを再取得
      if (_periodDays != 7) {
        _fetchAllLogs();
      }
    }
  }

  Future<void> _changePeriod(int days) async {
    if (days == _periodDays) return;
    setState(() => _periodDays = days);

    // 全データ未取得なら取得（全タブでスクロール用に必要）
    if (_allLogs == null) {
      await _fetchAllLogs();
    }
  }

  Future<void> _fetchAllLogs() async {
    setState(() => _loadingMore = true);
    try {
      final logs = await widget.service.getLastNDays(365);
      if (mounted) setState(() => _allLogs = logs);
    } catch (e) {
      debugPrint('データ読み込み失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('データの読み込みに失敗しました')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _fetchPredictions() async {
    try {
      final preds = await widget.service.getLastNPredictions(90);
      if (mounted) setState(() => _predictions = preds);
    } catch (e) {
      debugPrint('予測データ読み込み失敗: $e');
    }
  }

  void _openDailyEdit(String dateKey, bool editable) async {
    final log = await widget.service.getLogForDate(dateKey);
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailyInputPage(
          service: widget.service,
          todayLog: log,
          onSaved: widget.onReload,
          dateKey: dateKey,
          readOnly: !editable,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = _displayLogs;

    return Scaffold(
      appBar: AppBar(title: const Text('データ')),
      body: RefreshIndicator(
        onRefresh: widget.onReload,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),

              // --- 期間切替 ---
              Row(
                children: [
                  _periodPill(7, '7日', Icons.swipe, 'スライド'),
                  const SizedBox(width: AppSpacing.sm),
                  _periodPill(30, '30日', Icons.swipe, 'スライド'),
                  const SizedBox(width: AppSpacing.sm),
                  _periodPill(0, '全期間', Icons.fullscreen, '一覧'),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              if (_loadingMore)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                // --- 体調グラフ ---
                SectionHeader(title: '体調推移'),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Chart7Days(
                    logs: logs,
                    periodDays: _periodDays,
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // --- 体調×特徴量 比較グラフ ---
                SectionHeader(title: '体調と生活データの比較'),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: ComparisonChart(
                    logs: logs,
                    periodDays: _periodDays,
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // --- 睡眠パターン ---
                SectionHeader(title: '睡眠パターン'),
                const SizedBox(height: AppSpacing.sm),
                AppCard(child: SleepPatternChart(
                  logs: logs.length > 7
                      ? logs.sublist(logs.length - 7)
                      : logs,
                )),

                const SizedBox(height: AppSpacing.lg),

                // --- 予測 vs 実績 ---
                SectionHeader(title: '予測と実績の振り返り'),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: PredictionAccuracyChart(
                    logs: logs,
                    predictions: _predictions ?? [],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // --- 相関散布図 ---
                SectionHeader(title: '生活データと体調の相関'),
                const SizedBox(height: AppSpacing.sm),
                AppCard(child: CorrelationScatter(logs: logs)),

                const SizedBox(height: AppSpacing.lg),

                // --- カレンダー ---
                SectionHeader(title: '日次カレンダー'),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: CalendarView(
                    logs: logs,
                    onTap: _openDailyEdit,
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodPill(int days, String label, IconData icon, String subLabel) {
    final selected = _periodDays == days;
    return AppPill(
      label: label,
      selected: selected,
      icon: icon,
      subLabel: subLabel,
      onTap: () => _changePeriod(days),
    );
  }
}
