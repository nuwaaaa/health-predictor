import 'package:flutter/material.dart';
import '../models/model_status.dart';

class StatusBanner extends StatelessWidget {
  final ModelStatus status;

  const StatusBanner({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final ready = status.ready;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ready ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ready ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Column(
        children: [
          Text(
            status.statusLabel,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '${status.daysCollected} / ${status.daysRequired} 日記録済み',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          if (ready) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _infoPill(
                  'モデル',
                  status.modelType == 'lightgbm' ? 'LightGBM' : 'ロジスティック',
                ),
                const SizedBox(width: 10),
                _infoPill('信頼度', status.confidenceLevelLabel),
                if (status.recentMissingRate > 0) ...[
                  const SizedBox(width: 10),
                  _infoPill(
                    '欠損率',
                    '${(status.recentMissingRate * 100).round()}%',
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(180),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 11, color: Colors.black54),
      ),
    );
  }
}
