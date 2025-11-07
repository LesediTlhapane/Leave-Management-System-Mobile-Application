// lib/home_screen.dart
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

import 'leave_balance_data.dart';   // ensureBalancesForUser, getBalances
import 'notification_data.dart';    // myNotifications
import 'notif_sync.dart';           // startNotificationsSyncForUser, stopNotificationsSync

class HomeScreen extends StatefulWidget {
  final Employee user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _brandBlue = Color(0xFF3B4D79);
  static const _heading   = Color(0xFF111827);
  static const _muted     = Color(0xFF6B7280);
  static const _border    = Color(0xFFE5E7EB);
  static const _bg        = Color(0xFFF5F7FB);

  final _db = FirebaseFirestore.instance;
  double _welcomeOpacity = 1.0;

  @override
  void initState() {
    super.initState();

    // local in-memory balances bootstrap
    ensureBalancesForUser(widget.user.id);

    // 🔔 start syncing notifications from Firestore (applies/approvals/rejections/cancels)
    startNotificationsSyncForUser(
      employeeId: widget.user.id,
      employeeName: widget.user.name,
      onAnyChange: () {
        if (mounted) setState(() {}); // ensure the bell count updates when new notifs arrive
      },
    );

    // fade-away for the welcome chip
    Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      setState(() => _welcomeOpacity = 0.0);
    });
  }

  @override
  void dispose() {
    // stop notifications stream
    stopNotificationsSync();
    super.dispose();
  }

  void _logout(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Logged out successfully")));
  }

  // ---- Balances (existing helpers) ------------------------------------------

  LeaveBalance? _balanceFor(String type) {
    final list = getBalances(widget.user.id);
    try {
      return list.firstWhere((b) => b.type == type);
    } catch (_) {
      return null;
    }
  }

  int? _allocated(String type) => _balanceFor(type)?.allocated;
  int? _remaining(String type) => _balanceFor(type)?.remaining;

  int? _totalAllocatedAnnualAndSick() {
    final a = _allocated("Annual Leave");
    final s = _allocated("Sick Leave");
    if (a == null || s == null) return null;
    return a + s;
  }

  // ---- UI bits --------------------------------------------------------------

  Widget _welcomeChip() {
    return AnimatedOpacity(
      opacity: _welcomeOpacity,
      duration: const Duration(milliseconds: 600),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF4FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD7E3FF)),
        ),
        child: Row(
          children: [
            const Icon(Icons.waving_hand_outlined, color: _brandBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Welcome, ${widget.user.name}!",
                style: const TextStyle(
                  color: _brandBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewCard({
    required IconData icon,
    required String title,
    required String bigValue,
  }) {
    return Expanded(
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, 4))
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: _brandBlue),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700)),
            ]),
            const Spacer(),
            Text(
              bigValue,
              style: const TextStyle(
                color: _brandBlue,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _heading,
        fontWeight: FontWeight.w800,
        fontSize: 15.5,
      ),
    );
  }

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
          BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFF3F4F6),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : "?",
              style: const TextStyle(color: _brandBlue, fontWeight: FontWeight.w800),
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
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 2),
                Text(leaveType, style: const TextStyle(color: _muted, fontSize: 12.5)),
                const SizedBox(height: 8),
                Text(dateRange, style: const TextStyle(color: _heading)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(.1),
                        border: Border.all(color: badgeColor.withOpacity(.3)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MyLeavesScreen(user: widget.user)),
                        );
                      },
                      child: Row(
                        children: const [
                          Text("View", style: TextStyle(color: _muted, fontWeight: FontWeight.w700)),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_right_alt_rounded, color: _muted),
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

  Widget _balanceTile({required String type, required IconData icon}) {
    final rem = _remaining(type);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LeaveBalancesScreen(user: widget.user)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, 4))
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Icon(icon, color: _brandBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                type,
                style: const TextStyle(color: _heading, fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              rem == null ? "Unlimited" : "${rem} Days",
              style: const TextStyle(
                color: _brandBlue,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onMenuSelected(BuildContext context, String value) {
    final u = widget.user;
    switch (value) {
      case 'Apply for Leave':
        Navigator.push(context, MaterialPageRoute(builder: (_) => ApplyLeaveScreen(user: u)))
            .then((_) => setState(() {}));
        break;
      case 'My Leaves':
        Navigator.push(context, MaterialPageRoute(builder: (_) => MyLeavesScreen(user: u)))
            .then((_) => setState(() {}));
        break;
      case 'Leave Balance':
        Navigator.push(context, MaterialPageRoute(builder: (_) => LeaveBalancesScreen(user: u)))
            .then((_) => setState(() {}));
        break;
      case 'Notifications':
        Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen(user: u)))
            .then((_) => setState(() {})); // refresh bell after return
        break;
      case 'Profile':
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(user: u)));
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$value selected')));
    }
  }

  String _dateText(dynamic v) {
    if (v is String) return v;
    if (v is Timestamp) {
      final d = v.toDate();
      return "${d.day}/${d.month}/${d.year}";
    }
    return '—';
  }

  // Small badge for notifications in AppBar
  Widget _notifIconWithBadge(BuildContext context) {
    final totalForUser = myNotifications.where((n) => n.employeeId == widget.user.id).length;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_outlined, color: _brandBlue),
          tooltip: 'Notifications',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NotificationsScreen(user: widget.user)),
            ).then((_) => setState(() {}));
          },
        ),
        if (totalForUser > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                totalForUser > 99 ? "99+" : "$totalForUser",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;

    // Live query: employeeId + createdAt desc (composite index).
    final q = _db
        .collection('leave_requests')
        .where('employeeId', isEqualTo: u.id)
        .orderBy('createdAt', descending: true);

    final totalEntitlement = _totalAllocatedAnnualAndSick();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          "Home",
          style: TextStyle(color: _heading, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.logout_rounded, color: _brandBlue),
          tooltip: 'Logout',
          onPressed: () => _logout(context),
        ),
        actions: [
          _notifIconWithBadge(context), // 🔔
          IconButton(
            icon: const Icon(Icons.person_outline, color: _brandBlue),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileScreen(user: u)),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: q.snapshots(),
        builder: (context, snap) {
          // Top (overview gets rendered AFTER we compute approved days)
          final top = <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.menu, size: 40, color: _brandBlue),
                  onSelected: (value) => _onMenuSelected(context, value),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'Apply for Leave',
                      child: Row(children: [Icon(Icons.edit, color: _brandBlue), SizedBox(width: 8), Text('Apply for Leave')]),
                    ),
                    PopupMenuItem(
                      value: 'My Leaves',
                      child: Row(children: [Icon(Icons.list_alt, color: _brandBlue), SizedBox(width: 8), Text('My Leaves')]),
                    ),
                    PopupMenuItem(
                      value: 'Leave Balance',
                      child: Row(children: [Icon(Icons.bar_chart, color: _brandBlue), SizedBox(width: 8), Text('Leave Balance')]),
                    ),
                    PopupMenuItem(
                      value: 'Notifications',
                      child: Row(children: [Icon(Icons.notifications, color: _brandBlue), SizedBox(width: 8), Text('Notifications')]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            _welcomeChip(),
            const SizedBox(height: 16),
            _sectionHeader("Overview"),
            const SizedBox(height: 10),
          ];

          if (snap.hasError) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                ...top,
                Row(
                  children: [
                    _overviewCard(
                      icon: Icons.card_giftcard_outlined,
                      title: "Total Leave Days",
                      bigValue: totalEntitlement == null ? "Unlimited" : "${totalEntitlement} Days",
                    ),
                    const SizedBox(width: 10),
                    _overviewCard(
                      icon: Icons.event_available_outlined,
                      title: "Leave Taken YTD",
                      bigValue: "–",
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text("Error loading requests: ${snap.error}", style: const TextStyle(color: _muted)),
                ),
                const SizedBox(height: 18),
                _sectionHeader("Leave Balances"),
                const SizedBox(height: 10),
                _balanceTile(type: "Annual Leave", icon: Icons.card_travel),
                const SizedBox(height: 10),
                _balanceTile(type: "Sick Leave", icon: Icons.local_hospital_outlined),
              ],
            );
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Split into statuses and compute APPROVED YTD days from Firestore
          final docs = snap.data!.docs;

          final isTrackedType = (String? t) =>
              t == "Annual Leave" || t == "Sick Leave"; // adjust if needed

          int approvedYtdDays = 0;
          final pending = <QueryDocumentSnapshot>[];
          final approved = <QueryDocumentSnapshot>[];
          final rejected = <QueryDocumentSnapshot>[];

          for (final d in docs) {
            final m = d.data() as Map<String, dynamic>? ?? {};
            final s = (m['status'] ?? 'pending').toString();
            if (s == 'approved') {
              approved.add(d);
              // Count only selected types toward YTD
              final lt = m['leaveType']?.toString();
              if (isTrackedType(lt)) {
                final numDays = (m['totalDays'] is num) ? (m['totalDays'] as num).toInt() : 0;
                approvedYtdDays += numDays;
              }
            } else if (s == 'rejected') {
              rejected.add(d);
            } else if (s == 'cancelled') {
              // ignore in dashboard lists
            } else {
              pending.add(d);
            }
          }

          // Build sections
          final body = <Widget>[
            // Overview row (now that we know approvedYtdDays)
            Row(
              children: [
                _overviewCard(
                  icon: Icons.card_giftcard_outlined,
                  title: "Total Leave Days",
                  bigValue: totalEntitlement == null ? "Unlimited" : "${totalEntitlement} Days",
                ),
                const SizedBox(width: 10),
                _overviewCard(
                  icon: Icons.event_available_outlined,
                  title: "Leave Taken YTD",
                  bigValue: "$approvedYtdDays Days", // ✅ only approved count
                ),
              ],
            ),

            const SizedBox(height: 18),
            _sectionHeader("Pending Requests"),
            const SizedBox(height: 10),
            if (pending.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text("No pending requests.", style: TextStyle(color: _muted)),
              )
            else
              ...pending.map((d) {
                final m = d.data() as Map<String, dynamic>? ?? {};
                final name = (m['employeeName'] ?? '').toString();
                final type = (m['leaveType'] ?? '').toString();
                final start = _dateText(m['startDateText'] ?? m['startDate']);
                final end   = _dateText(m['endDateText'] ?? m['endDate']);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _requestTile(
                    name: name,
                    leaveType: type,
                    dateRange: "$start - $end",
                    badgeColor: const Color(0xFFF59E0B),
                    badgeText: "Pending",
                  ),
                );
              }),

            const SizedBox(height: 12),
            _sectionHeader("Approved Leave"),
            const SizedBox(height: 10),
            if (approved.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text("No approved leave yet.", style: TextStyle(color: _muted)),
              )
            else
              ...approved.map((d) {
                final m = d.data() as Map<String, dynamic>? ?? {};
                final name = (m['employeeName'] ?? '').toString();
                final type = (m['leaveType'] ?? '').toString();
                final start = _dateText(m['startDateText'] ?? m['startDate']);
                final end   = _dateText(m['endDateText'] ?? m['endDate']);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _requestTile(
                    name: name,
                    leaveType: type,
                    dateRange: "$start - $end",
                    badgeColor: const Color(0xFF16A34A),
                    badgeText: "Approved",
                  ),
                );
              }),

            const SizedBox(height: 12),
            _sectionHeader("Rejected Leave"),
            const SizedBox(height: 10),
            if (rejected.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text("No rejected requests.", style: TextStyle(color: _muted)),
              )
            else
              ...rejected.map((d) {
                final m = d.data() as Map<String, dynamic>? ?? {};
                final name = (m['employeeName'] ?? '').toString();
                final type = (m['leaveType'] ?? '').toString();
                final start = _dateText(m['startDateText'] ?? m['startDate']);
                final end   = _dateText(m['endDateText'] ?? m['endDate']);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _requestTile(
                    name: name,
                    leaveType: type,
                    dateRange: "$start - $end",
                    badgeColor: const Color(0xFFE11D48),
                    badgeText: "Rejected",
                  ),
                );
              }),

            const SizedBox(height: 18),
            _sectionHeader("Leave Balances"),
            const SizedBox(height: 10),
            _balanceTile(type: "Annual Leave", icon: Icons.card_travel),
            const SizedBox(height: 10),
            _balanceTile(type: "Sick Leave", icon: Icons.local_hospital_outlined),
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              ...top,
              ...body,
            ],
          );
        },
      ),
    );
  }
}
