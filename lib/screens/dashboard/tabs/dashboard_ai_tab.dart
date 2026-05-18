import 'package:flutter/material.dart';

import '../widgets/dashboard_ai_section.dart';

/// แท็บ 4: "วิเคราะห์ AI" — แสดงผลการวิเคราะห์ Gemini AI
class DashboardAiTab extends StatelessWidget {
  final String aiAnalysis;
  final bool isAnalyzing;
  final VoidCallback onStart;
  final VoidCallback onRefresh;

  const DashboardAiTab({
    super.key,
    required this.aiAnalysis,
    required this.isAnalyzing,
    required this.onStart,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          DashboardAiSection(
            aiAnalysis: aiAnalysis,
            isAnalyzing: isAnalyzing,
            onStart: onStart,
            onRefresh: onRefresh,
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
