import 'package:flutter/material.dart';

/// ส่วนสนทนากับ AI (Gemini)
class DashboardAiSection extends StatefulWidget {
  final List<Map<String, String>> chatHistory;
  final bool isAnalyzing;
  final void Function(String persona) onStartChat;
  final void Function(String text) onSendMessage;
  final VoidCallback onClearChat;

  const DashboardAiSection({
    super.key,
    required this.chatHistory,
    required this.isAnalyzing,
    required this.onStartChat,
    required this.onSendMessage,
    required this.onClearChat,
  });

  @override
  State<DashboardAiSection> createState() => _DashboardAiSectionState();
}

class _DashboardAiSectionState extends State<DashboardAiSection> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleSend() {
    if (_controller.text.trim().isEmpty) return;
    widget.onSendMessage(_controller.text);
    _controller.clear();
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chatHistory.isEmpty) {
      return _buildStartScreen();
    }

    return Container(
      height: 600, // Fixed height for chat window
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurple.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text('AI ผู้ช่วยร้าน (Gemini)',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple)),
                const Spacer(),
                TextButton.icon(
                  onPressed: widget.onClearChat,
                  icon: const Icon(Icons.clear_all, color: Colors.deepPurple),
                  label: const Text('เริ่มใหม่',
                      style: TextStyle(color: Colors.deepPurple)),
                ),
              ],
            ),
          ),

          // Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount:
                  widget.chatHistory.length + (widget.isAnalyzing ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == widget.chatHistory.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final msg = widget.chatHistory[index];
                final isUser = msg['role'] == 'user';
                return _buildMessageBubble(msg['text'] ?? '', isUser);
              },
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'พิมพ์ข้อความถาม AI...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  onPressed: widget.isAnalyzing ? null : _handleSend,
                  backgroundColor: Colors.deepPurple,
                  elevation: 0,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartScreen() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.support_agent, size: 64, color: Colors.deepPurple),
          const SizedBox(height: 16),
          const Text('เลือกผู้ช่วย AI ของคุณ',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple)),
          const SizedBox(height: 8),
          const Text(
              'ผู้ช่วยสามารถดึงข้อมูลยอดขาย ลูกหนี้ สินค้าคงคลัง และรายจ่าย มาตอบคำถามได้',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPersonaCard(
                title: 'สมปอง (นักวิเคราะห์)',
                description: 'ช่วยวิเคราะห์ยอดขายและสินค้า',
                icon: Icons.trending_up,
                onTap: () => widget.onStartChat('analyst'),
              ),
              const SizedBox(width: 24),
              _buildPersonaCard(
                title: 'สมศรี (นักบัญชี)',
                description: 'ช่วยตรวจสอบยอดลูกหนี้และรายจ่าย',
                icon: Icons.account_balance_wallet,
                onTap: () => widget.onStartChat('accountant'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonaCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.deepPurple),
            const SizedBox(height: 16),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.6,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? Colors.deepPurple : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight:
                isUser ? const Radius.circular(0) : const Radius.circular(16),
            bottomLeft:
                !isUser ? const Radius.circular(0) : const Radius.circular(16),
          ),
        ),
        child: SelectableText(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
