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
        ],
      ),
    );
  }
}
