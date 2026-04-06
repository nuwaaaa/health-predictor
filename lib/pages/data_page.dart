import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/calendar_view.dart';
import '../widgets/sleep_pattern_chart.dart';
import 'daily_input_page.dart';

/// データタブ — 記録ビューア
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
  List<DailyLog>? _allLogs;

  @override
  void initState() {
    super.initState();
    _fetchAllLogs();
  }

  Future<void> _fetchAllLogs() async {
    try {
      final logs = await widget.service.getLastNDays(365);
      if (mounted) setState(() => _allLogs = logs);
    } catch (e) {
      debugPrint('カレンダーデータ読み込み失敗: $e');
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
    final recentLogs = widget.logs;
    final calendarLogs = _allLogs ?? recentLogs;

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

              // --- 睡眠パターン ---
              SectionHeader(title: '睡眠パターン'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(child: SleepPatternChart(
                logs: recentLogs.length > 7
                    ? recentLogs.sublist(recentLogs.length - 7)
                    : recentLogs,
              )),

              const SizedBox(height: AppSpacing.lg),

              // --- カレンダー ---
              SectionHeader(title: '日次カレンダー'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: CalendarView(
                  logs: calendarLogs,
                  onTap: _openDailyEdit,
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
