import 'package:flutter/material.dart';

/// ส่วนวิเคราะห์ด้วย AI (Gemini)
class DashboardAiSection extends StatelessWidget {
  final String aiAnalysis;
  final bool isAnalyzing;
  final VoidCallback onStart;
  final VoidCallback onRefresh;

  const DashboardAiSection({
    super.key,
    required this.aiAnalysis,
    required this.isAnalyzing,
    required this.onStart,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.deepPurple),
              const SizedBox(width: 8),
              const Text('วิเคราะห์ด้วย AI (Gemini)',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple)),
              const Spacer(),
              if (aiAnalysis.isEmpty)
                ElevatedButton.icon(
                  onPressed: isAnalyzing ? null : onStart,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('เริ่มวิเคราะห์'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.deepPurple),
                  onPressed: onRefresh,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (isAnalyzing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (aiAnalysis.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                aiAnalysis,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('กดปุ่มด้านบนเพื่อเริ่มการวิเคราะห์ยอดขายและกำไร',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
        ],
      ),
    );
  }
}
