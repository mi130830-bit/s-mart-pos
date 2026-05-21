import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/dashboard_controller.dart';
import '../widgets/dashboard_ai_section.dart';

/// แท็บ 4: "วิเคราะห์ AI" — แสดงผลการวิเคราะห์ Gemini AI
class DashboardAiTab extends ConsumerWidget {
  const DashboardAiTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          DashboardAiSection(
            aiAnalysis: state.aiAnalysis,
            isAnalyzing: state.isAnalyzing,
            onStart: () => notifier.fetchAiAnalysis(),
            onRefresh: () => notifier.fetchAiAnalysis(),
          ),
          const SizedBox(height: 20),
          const Text(
            'AI จะวิเคราะห์จากข้อมูลเมื่อกราฟแสดงผล (เดือนนี้ หรือ ปีนี้)',
            style: TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
