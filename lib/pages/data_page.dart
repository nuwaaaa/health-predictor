import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/chart_7days.dart';
import '../widgets/comparison_chart.dart';
import '../widgets/calendar_view.dart';
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
  List<DailyLog> _displayLogs = [];
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _displayLogs = widget.logs;
  }

  @override
  void didUpdateWidget(covariant DataPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_periodDays == 7) {
      _displayLogs = widget.logs;
    }
  }

  Future<void> _changePeriod(int days) async {
    if (days == _periodDays) return;
    setState(() {
      _periodDays = days;
      _loadingMore = true;
    });

    try {
      if (days == 7) {
        setState(() => _displayLogs = widget.logs);
      } else {
        final n = days == 0 ? 365 : days;
        final logs = await widget.service.getLastNDays(n);
        setState(() => _displayLogs = logs);
      }
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
                  _periodPill(7, '7日'),
                  const SizedBox(width: AppSpacing.sm),
                  _periodPill(30, '30日'),
                  const SizedBox(width: AppSpacing.sm),
                  _periodPill(0, '全期間'),
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
                AppCard(child: Chart7Days(logs: _displayLogs)),

                const SizedBox(height: AppSpacing.lg),

                // --- 体調×特徴量 比較グラフ ---
                SectionHeader(title: '体調と生活データの比較'),
                const SizedBox(height: AppSpacing.sm),
                AppCard(child: ComparisonChart(logs: _displayLogs)),

                const SizedBox(height: AppSpacing.lg),

                // --- カレンダー ---
                SectionHeader(title: '日次カレンダー'),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: CalendarView(
                    logs: _displayLogs,
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

  Widget _periodPill(int days, String label) {
    final selected = _periodDays == days;
    return AppPill(
      label: label,
      selected: selected,
      onTap: () => _changePeriod(days),
    );
  }
}
