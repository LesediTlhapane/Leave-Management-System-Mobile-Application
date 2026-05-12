// lib/ai_leave_assistant_screen.dart
// LeaveFlow — AI Leave Assistant Chatbot
// Uses Anthropic API via the claude-sonnet-4-20250514 model

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'employee_data.dart';
import 'leave_balance_data.dart';

class AiLeaveAssistantScreen extends StatefulWidget {
  final Employee user;
  const AiLeaveAssistantScreen({super.key, required this.user});

  @override
  State<AiLeaveAssistantScreen> createState() =>
      _AiLeaveAssistantScreenState();
}

class _AiLeaveAssistantScreenState extends State<AiLeaveAssistantScreen>
    with SingleTickerProviderStateMixin {
  final _controller      = TextEditingController();
  final _scrollController= ScrollController();
  final List<_Msg>  _msgs = [];
  bool _typing = false;

  // ── brand colours ──────────────────────────────────────────
  static const _navy   = Color(0xFF1E2D5A);
  static const _blue   = Color(0xFF3B4D79);
  static const _accent = Color(0xFF6C8EF5);
  static const _bg     = Color(0xFFF5F7FB);
  static const _border = Color(0xFFE5E7EB);
  static const _muted  = Color(0xFF6B7280);

  // Quick-reply suggestions
  static const _quickReplies = [
    "How many leave days do I have left?",
    "What types of leave can I apply for?",
    "Can I take leave during a public holiday?",
    "How do I apply for sick leave?",
    "What is the leave carry-over policy?",
  ];

  @override
  void initState() {
    super.initState();
    // Greeting
    _msgs.add(_Msg(
      text:
          "Hi ${widget.user.name.split(' ').first}! 👋 I'm your AI leave assistant. "
          "I can help you with leave policies, balance queries, application guidance, "
          "and smart leave planning. What would you like to know?",
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _buildSystemPrompt() {
    final balances = getBalances(widget.user.id);
    final balanceSummary = balances.map((b) {
      if (b.allocated != null && b.remaining != null) {
        return "${b.type}: ${b.remaining} remaining of ${b.allocated}";
      }
      return "${b.type}: unlimited";
    }).join(", ");

    return """
You are LeaveFlow AI — a friendly, professional leave management assistant for employees.

EMPLOYEE CONTEXT:
- Name: ${widget.user.name}
- ID: ${widget.user.id}
- Department: ${widget.user.department}
- Position: ${widget.user.position}
- Leave Balances: $balanceSummary

YOUR ROLE:
- Help the employee understand their leave balances, policies, and how to apply
- Provide smart leave planning suggestions (best times to take leave, bridge days, etc.)
- Answer questions about leave types: Annual, Sick, Family Responsibility, Unpaid, Maternity/Paternity
- Keep responses concise, warm, and helpful
- Use bullet points for lists; keep answers under 150 words unless detail is needed
- Never make up policies — give general South African labour law guidance when unsure
- Always refer to the employee by their first name

SOUTH AFRICAN LEAVE BASICS (if asked):
- Annual Leave: 15 working days per year (BCEA minimum)
- Sick Leave: 30 days per 3-year cycle
- Family Responsibility: 3 days per year
- Maternity: 4 months unpaid (BCEA); UIF may apply
- Public holidays do not count as leave days
""";
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _msgs.add(_Msg(text: text.trim(), isUser: true));
      _typing = true;
    });
    _controller.clear();
    _scrollDown();

    try {
      // Build conversation history for context
      final history = _msgs
          .where((m) => m.text != _msgs.first.text) // skip greeting
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.text,
              })
          .toList();

      // Ensure last message is user's
      if (history.isNotEmpty && history.last['role'] == 'assistant') {
        history.removeLast();
      }

      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-sonnet-4-20250514',
          'max_tokens': 600,
          'system': _buildSystemPrompt(),
          'messages': [
            ...history,
            {'role': 'user', 'content': text.trim()},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = (data['content'] as List)
            .where((b) => b['type'] == 'text')
            .map((b) => b['text'] as String)
            .join('\n');

        setState(() {
          _msgs.add(_Msg(text: reply, isUser: false));
          _typing = false;
        });
      } else {
        _fallback();
      }
    } catch (_) {
      _fallback();
    }
    _scrollDown();
  }

  void _fallback() {
    setState(() {
      _msgs.add(_Msg(
        text:
            "I'm having trouble connecting right now. Please check your internet connection and try again.",
        isUser: false,
      ));
      _typing = false;
    });
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessages()),
          if (_typing) _buildTypingIndicator(),
          _buildQuickReplies(),
          _buildInputBar(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _navy),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5B7BF8), Color(0xFF3B4D79)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Leave AI Assistant',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Text(
                'Powered by LeaveFlow AI',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _border),
      ),
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _msgs.length,
      itemBuilder: (_, i) => _buildBubble(_msgs[i]),
    );
  }

  Widget _buildBubble(_Msg msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5B7BF8), Color(0xFF3B4D79)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? _blue : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF111827),
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5B7BF8), Color(0xFF3B4D79)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return _TypingDot(delay: Duration(milliseconds: i * 200));
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickReplies() {
    return Container(
      height: 44,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _quickReplies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _sendMessage(_quickReplies[i]),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD7E3FF)),
            ),
            child: Text(
              _quickReplies[i],
              style: const TextStyle(
                color: _accent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _border),
              ),
              child: TextField(
                controller: _controller,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                style: const TextStyle(fontSize: 13.5),
                decoration: const InputDecoration(
                  hintText: 'Ask me anything about leave…',
                  hintStyle: TextStyle(color: _muted, fontSize: 13.5),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(_controller.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5B7BF8), Color(0xFF3B4D79)],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data model ───────────────────────────────────────────────────
class _Msg {
  final String text;
  final bool isUser;
  _Msg({required this.text, required this.isUser});
}

// ── Typing dot animation ─────────────────────────────────────────
class _TypingDot extends StatefulWidget {
  final Duration delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: const BoxDecoration(
          color: Color(0xFF3B4D79),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}