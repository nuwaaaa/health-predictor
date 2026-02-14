import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../services/firestore_service.dart';
import '../widgets/chart_7days.dart';
import '../widgets/comparison_chart.dart';
import '../widgets/daily_list.dart';
import '../widgets/sleep_pattern_chart.dart';
import 'daily_input_page.dart';

/// データタブ: 期間切替、比較グラフ、睡眠パターン、日次一覧（編集付き）
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
  int _periodDays = 7; // 7 / 30 / 0(全期間)
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('読み込み失敗: $e')),
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
    return RefreshIndicator(
      onRefresh: widget.onReload,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),

            // --- 期間切替 ---
            Row(
              children: [
                _periodChip(7, '7日'),
                const SizedBox(width: 8),
                _periodChip(30, '30日'),
                const SizedBox(width: 8),
                _periodChip(0, '全期間'),
              ],
            ),

            const SizedBox(height: 20),

            if (_loadingMore)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              // --- 体調グラフ ---
              const Text('体調推移',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Chart7Days(logs: _displayLogs),

              const SizedBox(height: 24),

              // --- 体調×特徴量 比較グラフ ---
              const Text('体調と生活データの比較',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ComparisonChart(logs: _displayLogs),

              const SizedBox(height: 24),

              // --- 睡眠パターン ---
              const Text('睡眠パターン',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SleepPatternChart(logs: _displayLogs),

              const SizedBox(height: 24),

              // --- 日次一覧 ---
              const Text('日次一覧',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              DailyList(
                logs: _displayLogs,
                onTap: _openDailyEdit,
              ),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _periodChip(int days, String label) {
    final selected = _periodDays == days;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _changePeriod(days),
      selectedColor: Colors.blue.shade100,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        color: selected ? Colors.blue.shade800 : Colors.black54,
      ),
    );
  }
}
