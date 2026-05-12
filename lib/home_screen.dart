// lib/home_screen.dart
// LeaveFlow — Employee Home Screen
// Updated: matches login screen dark-navy theme, integrates 3 AI feature cards,
// adds AI features to the popup menu, replaces "Home" title with LeaveFlow wordmark.

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'employee_data.dart';
import 'apply_for_leave_screen.dart';
import 'my_leaves_screen.dart';
import 'notifications_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'leave_balances_screen.dart';

import 'leave_balance_data.dart';
import 'notification_data.dart';
import 'notif_sync.dart';

// ── AI feature screens (all three combined in one file) ────────
import 'ai_features.dart';

class HomeScreen extends StatefulWidget {
  final Employee user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {

  // ── Brand colours — matches login screen ───────────────────
  static const _navy    = Color(0xFF1E2D5A);
  static const _blue    = Color(0xFF3B4D79);
  static const _accent  = Color(0xFF6C8EF5);
  static const _bg      = Color(0xFFF5F7FB);
  static const _heading = Color(0xFF111827);
  static const _muted   = Color(0xFF6B7280);
  static const _border  = Color(0xFFE5E7EB);

  final _db = FirebaseFirestore.instance;
  double _welcomeOpacity = 1.0;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    ensureBalancesForUser(widget.user.id);
    // Sync balances from Firestore so they survive app restarts
    syncBalancesFromFirestore(widget.user.id).then((_) {
      if (mounted) setState(() {});
    });

    startNotificationsSyncForUser(
      employeeId: widget.user.id,
      employeeName: widget.user.name,
      onAnyChange: () { if (mounted) setState(() {}); },
    );

    Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      setState(() => _welcomeOpacity = 0.0);
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    stopNotificationsSync();
    super.dispose();
  }

  // ── Balance helpers ─────────────────────────────────────────
  LeaveBalance? _balanceFor(String type) {
    try {
      return getBalances(widget.user.id).firstWhere((b) => b.type == type);
    } catch (_) { return null; }
  }

  int? _remaining(String type) => _balanceFor(type)?.remaining;
  int? _allocated(String type) => _balanceFor(type)?.allocated;

  int? _totalAllocatedAnnualAndSick() {
    final a = _allocated("Annual Leave");
    final s = _allocated("Sick Leave");
    if (a == null || s == null) return null;
    return a + s;
  }

  // ── Navigation ──────────────────────────────────────────────
  void _go(Widget screen) {
    Navigator.push(context, _fadeRoute(screen)).then((_) => setState(() {}));
  }

  PageRoute _fadeRoute(Widget screen) => PageRouteBuilder(
    pageBuilder: (_, a, __) => screen,
    transitionsBuilder: (_, a, __, child) =>
        FadeTransition(opacity: a, child: child),
    transitionDuration: const Duration(milliseconds: 300),
  );

  void _logout() {
    stopNotificationsSync();
    Navigator.pushAndRemoveUntil(
      context,
      _fadeRoute(const LoginScreen()),
      (route) => false,
    );
  }

  void _onMenuSelected(String value) {
    final u = widget.user;
    switch (value) {
      case 'apply':       _go(ApplyLeaveScreen(user: u));           break;
      case 'my_leaves':   _go(MyLeavesScreen(user: u));             break;
      case 'balance':     _go(LeaveBalancesScreen(user: u));        break;
      case 'notifs':      _go(NotificationsScreen(user: u));        break;
      case 'profile':     _go(ProfileScreen(user: u));              break;
      case 'ai_chat':     _go(AiLeaveAssistantScreen(user: u));     break;
      case 'ai_planner':  _go(SmartLeavePlanningScreen(user: u));   break;
      case 'wellbeing':   _go(WellbeingScreen(user: u));            break;
    }
  }

  // ── Date helper ─────────────────────────────────────────────
  String _dateText(dynamic v) {
    if (v is String) return v;
    if (v is Timestamp) {
      final d = v.toDate();
      return "${d.day}/${d.month}/${d.year}";
    }
    return '—';
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final q = _db
        .collection('leave_requests')
        .where('employeeId', isEqualTo: u.id)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(u),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: StreamBuilder<QuerySnapshot>(
          stream: q.snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: _accent,
                  strokeWidth: 2.5,
                ),
              );
            }

            if (snap.hasError) {
              return _buildErrorState(snap.error);
            }

            return _buildBody(snap.data!.docs);
          },
        ),
      ),
    );
  }

  // ── App bar ─────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(Employee u) {
    final notifCount = myNotifications
        .where((n) => n.employeeId == u.id)
        .length;

    return AppBar(
      elevation: 0,
      backgroundColor: _navy,
      surfaceTintColor: _navy,

      // LeaveFlow wordmark (left)
      title: RichText(
        text: const TextSpan(
          children: [
            TextSpan(
              text: 'Leave',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            TextSpan(
              text: 'Flow',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 22,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6C8EF5),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),

      leading: IconButton(
        icon: const Icon(Icons.logout_rounded, color: Colors.white70),
        tooltip: 'Logout',
        onPressed: _logout,
      ),

      actions: [
        // Notification bell
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_outlined,
                  color: Colors.white),
              onPressed: () => _onMenuSelected('notifs'),
            ),
            if (notifCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    notifCount > 99 ? '99+' : '$notifCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),

        // Profile
        IconButton(
          icon: const Icon(Icons.person_outline_rounded,
              color: Colors.white),
          onPressed: () => _onMenuSelected('profile'),
        ),

        // Hamburger menu
        _buildHamburger(),
        const SizedBox(width: 4),
      ],

      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: Colors.white.withOpacity(0.1),
        ),
      ),
    );
  }

  // ── Hamburger popup menu ────────────────────────────────────
  Widget _buildHamburger() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 8,
      onSelected: _onMenuSelected,
      itemBuilder: (_) => [
        // ── Standard actions ───────────────────────────
        _menuItem('apply',      Icons.edit_note_outlined,       'Apply for Leave'),
        _menuItem('my_leaves',  Icons.list_alt_outlined,        'My Leaves'),
        _menuItem('balance',    Icons.bar_chart_rounded,        'Leave Balance'),
        _menuItem('notifs',     Icons.notifications_none_outlined, 'Notifications'),
        const PopupMenuDivider(),

        // ── AI Features ────────────────────────────────
        _menuHeader('AI Features'),
        _menuItem('ai_chat',    Icons.auto_awesome,             'AI Leave Assistant',
            badge: 'NEW', badgeColor: _accent),
        _menuItem('ai_planner', Icons.lightbulb_outline,        'Smart Leave Planner',
            badge: 'AI', badgeColor: const Color(0xFF059669)),
        _menuItem('wellbeing',  Icons.favorite_outline,         'Wellbeing & Burnout',
            badge: 'YOU', badgeColor: const Color(0xFFA855F7)),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    String? badge,
    Color? badgeColor,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 46,
      child: Row(
        children: [
          Icon(icon, color: _blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _heading,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (badgeColor ?? _accent).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: badgeColor ?? _accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuHeader(String label) {
    return PopupMenuItem<String>(
      enabled: false,
      height: 32,
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: _muted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  // ── Main body ───────────────────────────────────────────────
  Widget _buildBody(List<QueryDocumentSnapshot> docs) {
    final totalEntitlement = _totalAllocatedAnnualAndSick();

    int approvedYtdDays = 0;
    final pending  = <QueryDocumentSnapshot>[];
    final approved = <QueryDocumentSnapshot>[];
    final rejected = <QueryDocumentSnapshot>[];

    for (final d in docs) {
      final m = d.data() as Map<String, dynamic>? ?? {};
      final s = (m['status'] ?? 'pending').toString();
      if (s == 'approved') {
        approved.add(d);
        // Count ALL tracked leave types toward YTD total
        final lt = m['leaveType']?.toString() ?? '';
        const unlimited = ['Special Leave', 'Unpaid Leave'];
        if (lt.isNotEmpty && !unlimited.contains(lt)) {
          approvedYtdDays += (m['totalDays'] is num)
              ? (m['totalDays'] as num).toInt()
              : 0;
        }
      } else if (s == 'rejected') {
        rejected.add(d);
      } else if (s != 'cancelled') {
        pending.add(d);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [

        // ── Welcome banner ─────────────────────────────
        _buildWelcomeBanner(),
        const SizedBox(height: 16),

        // ── Overview cards ─────────────────────────────
        _buildSectionLabel('Overview'),
        const SizedBox(height: 10),
        Row(
          children: [
            _overviewCard(
              icon: Icons.card_giftcard_outlined,
              label: 'Total Leave Days',
              value: totalEntitlement == null
                  ? 'Unlimited'
                  : '$totalEntitlement Days',
            ),
            const SizedBox(width: 10),
            _overviewCard(
              icon: Icons.event_available_outlined,
              label: 'Leave Taken YTD',
              value: '$approvedYtdDays Days',
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── AI Feature cards ───────────────────────────
        _buildSectionLabel('Smart Features'),
        const SizedBox(height: 10),
        _aiFeatureCard(
          icon:      Icons.auto_awesome,
          label:     'AI Leave Assistant',
          subtitle:  'Ask anything about leave policies, balances & rules',
          gradient:  const [Color(0xFF3B4D79), Color(0xFF6C8EF5)],
          glow:      const Color(0xFF6C8EF5),
          badge:     'NEW',
          onTap:     () => _onMenuSelected('ai_chat'),
        ),
        const SizedBox(height: 10),
        _aiFeatureCard(
          icon:      Icons.lightbulb_outline,
          label:     'Smart Leave Planner',
          subtitle:  'Optimise leave around SA public holidays',
          gradient:  const [Color(0xFF065F46), Color(0xFF34D399)],
          glow:      const Color(0xFF059669),
          badge:     'AI',
          onTap:     () => _onMenuSelected('ai_planner'),
        ),
        const SizedBox(height: 10),
        _aiFeatureCard(
          icon:      Icons.favorite_outline,
          label:     'Wellbeing & Burnout',
          subtitle:  'Your personal wellbeing score & burnout risk',
          gradient:  const [Color(0xFF7C2D87), Color(0xFFC084FC)],
          glow:      const Color(0xFFA855F7),
          badge:     'YOU',
          onTap:     () => _onMenuSelected('wellbeing'),
        ),
        const SizedBox(height: 20),

        // ── Quick Actions row ──────────────────────────
        _buildSectionLabel('Quick Actions'),
        const SizedBox(height: 10),
        _buildQuickActions(),
        const SizedBox(height: 20),

        // ── Pending requests ───────────────────────────
        _buildSectionLabel('Pending Requests'),
        const SizedBox(height: 10),
        _buildLeaveList(
          docs: pending,
          emptyText: 'No pending requests.',
          badgeColor: const Color(0xFFF59E0B),
          badgeText: 'Pending',
        ),
        const SizedBox(height: 16),

        // ── Approved ───────────────────────────────────
        _buildSectionLabel('Approved Leave'),
        const SizedBox(height: 10),
        _buildLeaveList(
          docs: approved,
          emptyText: 'No approved leave yet.',
          badgeColor: const Color(0xFF16A34A),
          badgeText: 'Approved',
        ),
        const SizedBox(height: 16),

        // ── Rejected ───────────────────────────────────
        _buildSectionLabel('Rejected Leave'),
        const SizedBox(height: 10),
        _buildLeaveList(
          docs: rejected,
          emptyText: 'No rejected requests.',
          badgeColor: const Color(0xFFE11D48),
          badgeText: 'Rejected',
        ),
        const SizedBox(height: 16),

        // ── Leave Balances ─────────────────────────────
        _buildSectionLabel('Leave Balances'),
        const SizedBox(height: 10),
        _balanceTile(type: 'Annual Leave', icon: Icons.card_travel_outlined),
        const SizedBox(height: 10),
        _balanceTile(type: 'Sick Leave',   icon: Icons.local_hospital_outlined),
      ],
    );
  }

  // ── Welcome banner ──────────────────────────────────────────
  Widget _buildWelcomeBanner() {
    return AnimatedOpacity(
      opacity: _welcomeOpacity,
      duration: const Duration(milliseconds: 600),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E2D5A), Color(0xFF3B4D79)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _navy.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  widget.user.name.isNotEmpty
                      ? widget.user.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, ${widget.user.name.split(' ').first}! 👋',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.user.position,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accent.withOpacity(0.4)),
              ),
              child: Text(
                widget.user.id,
                style: const TextStyle(
                  color: Color(0xFFB4C6FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section label ───────────────────────────────────────────
  Widget _buildSectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: _heading,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  // ── Overview cards ──────────────────────────────────────────
  Widget _overviewCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        height: 86,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0C000000),
                blurRadius: 10,
                offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _blue, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: _navy,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AI feature card ─────────────────────────────────────────
  Widget _aiFeatureCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required List<Color> gradient,
    required Color glow,
    required String badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: glow.withOpacity(0.30),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(7),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white70,
                  size: 13,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick action buttons row ────────────────────────────────
  Widget _buildQuickActions() {
    return Row(
      children: [
        _quickBtn(
          icon: Icons.edit_note_outlined,
          label: 'Apply',
          onTap: () => _onMenuSelected('apply'),
        ),
        const SizedBox(width: 10),
        _quickBtn(
          icon: Icons.list_alt_outlined,
          label: 'My Leaves',
          onTap: () => _onMenuSelected('my_leaves'),
        ),
        const SizedBox(width: 10),
        _quickBtn(
          icon: Icons.bar_chart_rounded,
          label: 'Balance',
          onTap: () => _onMenuSelected('balance'),
        ),
      ],
    );
  }

  Widget _quickBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: _blue, size: 18),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: const TextStyle(
                  color: _heading,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Leave list (pending / approved / rejected) ──────────────
  Widget _buildLeaveList({
    required List<QueryDocumentSnapshot> docs,
    required String emptyText,
    required Color badgeColor,
    required String badgeText,
  }) {
    if (docs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(emptyText,
            style: const TextStyle(color: _muted, fontSize: 13)),
      );
    }

    return Column(
      children: docs.map((d) {
        final m    = d.data() as Map<String, dynamic>? ?? {};
        final name = (m['employeeName'] ?? '').toString();
        final type = (m['leaveType'] ?? '').toString();
        final start = _dateText(m['startDateText'] ?? m['startDate']);
        final end   = _dateText(m['endDateText']   ?? m['endDate']);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _requestTile(
            name: name,
            leaveType: type,
            dateRange: '$start – $end',
            badgeColor: badgeColor,
            badgeText: badgeText,
          ),
        );
      }).toList(),
    );
  }

  // ── Leave request tile ──────────────────────────────────────
  Widget _requestTile({
    required String name,
    required String leaveType,
    required String dateRange,
    required Color badgeColor,
    required String badgeText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD7E3FF)),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: _blue,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                      color: _heading,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    )),
                const SizedBox(height: 2),
                Text(leaveType,
                    style: const TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.date_range_outlined,
                        size: 12, color: _muted),
                    const SizedBox(width: 4),
                    Text(dateRange,
                        style: const TextStyle(
                            color: _heading, fontSize: 12.5)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Status pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.1),
                        border: Border.all(
                            color: badgeColor.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // View link
                    GestureDetector(
                      onTap: () => _onMenuSelected('my_leaves'),
                      child: Row(
                        children: const [
                          Text('View',
                              style: TextStyle(
                                color: _muted,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              )),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded,
                              color: _muted, size: 11),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Leave balance tile ──────────────────────────────────────
  Widget _balanceTile({required String type, required IconData icon}) {
    final rem   = _remaining(type);
    final alloc = _allocated(type);
    final pct   = (rem != null && alloc != null && alloc > 0)
        ? (rem / alloc).clamp(0.0, 1.0)
        : null;
    final color = pct == null
        ? _accent
        : pct > 0.5
            ? const Color(0xFF059669)
            : pct > 0.25
                ? const Color(0xFFD97706)
                : const Color(0xFFDC2626);

    return GestureDetector(
      onTap: () => _onMenuSelected('balance'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0C000000),
                blurRadius: 10,
                offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: _blue, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    type,
                    style: const TextStyle(
                      color: _heading,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                Text(
                  rem == null ? 'Unlimited' : '$rem Days',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            if (pct != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFF3F4F6),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Error state ─────────────────────────────────────────────
  Widget _buildErrorState(Object? error) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildWelcomeBanner(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Error loading data: $error',
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}