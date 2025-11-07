// my_leaves_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'employee_data.dart';
import 'leave_data.dart';            // LeaveApplication, myLeaves (with .status & .firebaseId)
import 'notification_data.dart';     // myNotifications, NotificationModel
import 'leave_balance_data.dart';    // refundBalance (local fallback)

// If you use the Firestore cancel helper, keep this:
import 'fire_backend.dart';          // optional, for your cancel helper

class MyLeavesScreen extends StatefulWidget {
  final Employee user; // ✅ active user
  const MyLeavesScreen({super.key, required this.user});

  @override
  State<MyLeavesScreen> createState() => _MyLeavesScreenState();
}

class _MyLeavesScreenState extends State<MyLeavesScreen> {
  int? _selectedIndex; // index in filtered list

  static const _brandBlue = Color(0xFF3B4D79);
  static const _heading   = Color(0xFF111827);
  static const _muted     = Color(0xFF6B7280);
  static const _border    = Color(0xFFE5E7EB);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _statusSub;

  @override
  void initState() {
    super.initState();
    _attachLiveStatusListener();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  // ---- Live status sync: listen to this user's leave_requests and reflect statuses locally ----
  void _attachLiveStatusListener() {
    final q = _db
        .collection('leave_requests')
        .where('employeeId', isEqualTo: widget.user.id)
        .orderBy('createdAt', descending: true);

    _statusSub = q.snapshots().listen((snap) {
      bool changed = false;

      for (final d in snap.docs) {
        final data = d.data();
        final String status = (data['status'] ?? 'pending') as String;
        final String type   = (data['leaveType'] ?? '') as String;

        // Dates can be saved as startDateText/endDateText or startDate/endDate depending on your HTML/app
        final String startText = (data['startDateText'] ?? data['startDate'] ?? '') as String;
        final String endText   = (data['endDateText']   ?? data['endDate']   ?? '') as String;

        // Find the local LeaveApplication that matches this doc.
        // We match by leaveType + start/end text (which your Apply screen stores as DD/MM/YYYY).
        final idx = myLeaves.indexWhere((lv) =>
          lv.employeeId == widget.user.id &&
          lv.leaveType   == type &&
          lv.startDate   == startText &&
          lv.endDate     == endText
        );

        if (idx != -1) {
          final lv = myLeaves[idx];

          // If we don't have the id yet, attach it
          if (lv.firebaseId != d.id) {
            lv.firebaseId = d.id;
            changed = true;
          }

          // Update status if changed
          if (lv.status != status) {
            lv.status = status;
            changed = true;
          }
        }
      }

      if (changed && mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _confirmAndCancel(LeaveApplication leave, int filteredIndex) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Cancel leave?"),
        content: const Text("This will remove the request and (if approved) return the days to your balance."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text("Yes, cancel")),
        ],
      ),
    ) ?? false;

    if (!ok) return;

    String snack = "Leave cancelled.";

    try {
      // Prefer the backend helper that refunds (if needed) and deletes the request doc
      final docId = leave.firebaseId;
      if (docId != null && docId.trim().isNotEmpty) {
        await cancelRequestAndRefund(
          docId: docId,
          employeeId: leave.employeeId,
          leaveType: leave.leaveType,
          totalDays: leave.totalDays,
          startDateText: leave.startDate,
          endDateText: leave.endDate,
          deleteDoc: true, // ensures website removes it
        );
        snack = "Leave cancelled — removed from server.";
      } else {
        // Fallback if we don't have a doc id (shouldn't happen once you save ids on create)
        await _cancelLeaveInFirestoreByQuery(leave);
        snack = "Leave cancelled — removed by query.";
      }
    } catch (e) {
      // If Firestore fails (e.g., offline), at least do local refund/remove so the app stays usable.
      refundBalance(
        employeeId: leave.employeeId,
        leaveType:  leave.leaveType,
        days:       leave.totalDays,
        note:       "Cancelled ${leave.startDate}–${leave.endDate} (local fallback)",
      );
      snack = "Leave cancelled locally (server sync failed).";
    }

    // Remove from local list (UI) no matter what
    setState(() {
      final globalIndex = myLeaves.indexOf(leave);
      if (globalIndex != -1) {
        myLeaves.removeAt(globalIndex);
      }
      _selectedIndex = null;
    });

    myNotifications.add(
      NotificationModel(
        title: "Leave Cancelled",
        message:
            "You cancelled your ${leave.leaveType} from ${leave.startDate} to ${leave.endDate}. ${leave.totalDays} day(s) returned (if previously approved).",
        timestamp: DateTime.now(),
        employeeId: widget.user.id,
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(snack)),
    );
  }

  /// Fallback: find + delete by query (used only when no firebaseId on the local model).
  Future<void> _cancelLeaveInFirestoreByQuery(LeaveApplication leave) async {
    final q = await _db
        .collection('leave_requests')
        .where('employeeId', isEqualTo: leave.employeeId)
        .where('leaveType',  isEqualTo: leave.leaveType)
        // match on either startDateText or startDate value
        .where('startDateText', isEqualTo: leave.startDate)
        .where('endDateText',   isEqualTo: leave.endDate)
        .limit(1)
        .get();

    if (q.docs.isEmpty) return;

    final reqRef = q.docs.first.reference;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(reqRef);
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>;
      final status     = (data['status'] ?? 'pending') as String;
      final days       = (data['totalDays'] ?? leave.totalDays) as int;
      final type       = (data['leaveType'] ?? leave.leaveType) as String;
      final employeeId = (data['employeeId'] ?? leave.employeeId) as String;

      // Refund if was approved
      if (status == 'approved') {
        final empRef = _db.collection('leave_balances').doc(employeeId);
        final empSnap = await tx.get(empRef);
        final bal = empSnap.exists ? (empSnap.data() as Map<String, dynamic>) : <String, dynamic>{};
        final rec = (bal[type] ?? <String, dynamic>{}) as Map<String, dynamic>;
        final remaining = (rec['remaining'] is num) ? (rec['remaining'] as num).toInt() : 0;
        rec['remaining'] = remaining + days;
        bal[type] = rec;
        tx.set(empRef, bal, SetOptions(merge: true));
      }

      // Notification audit
      final notifRef = _db.collection('notifications').doc();
      tx.set(notifRef, {
        'employeeId': employeeId,
        'title': 'Leave Cancelled',
        'message': '$type ${leave.startDate}–${leave.endDate} ($days day${days == 1 ? '' : 's'})',
        'status': 'cancelled',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Delete request
      tx.delete(reqRef);
    });
  }

  String _daysText(int d) => "$d day(s)";

  Widget _statusPill(String status) {
    // Colors by status
    Color color;
    Color border;
    Color bg;

    switch (status) {
      case 'approved':
        color  = const Color(0xFF16A34A);
        border = const Color(0xFFA7F3D0);
        bg     = const Color(0xFFECFDF5);
        break;
      case 'rejected':
        color  = const Color(0xFFE11D48);
        border = const Color(0xFFFECACA);
        bg     = const Color(0xFFFEF2F2);
        break;
      case 'cancelled':
        color  = const Color(0xFF6B7280);
        border = const Color(0xFFE5E7EB);
        bg     = const Color(0xFFF3F4F6);
        break;
      default: // pending
        color  = const Color(0xFFF59E0B);
        border = const Color(0xFFFDE68A);
        bg     = const Color(0xFFFFF7ED);
    }

    final label = status == 'approved'
        ? 'Approved'
        : status == 'rejected'
            ? 'Rejected'
            : status == 'cancelled'
                ? 'Cancelled'
                : 'Pending';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _labelValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
              color: _muted,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            )),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
              color: _heading,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            )),
      ],
    );
  }

  Widget _managerComment(String comment) {
    if (comment.trim().isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Row(
          children: [
            Icon(Icons.lock_person_outlined, size: 18, color: _muted),
            SizedBox(width: 6),
            Text(
              "Comment",
              style: TextStyle(
                color: _heading,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          comment,
          style: const TextStyle(
            color: _muted,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _cardForLeave(LeaveApplication leave, int filteredIndex) {
    final isSelected = _selectedIndex == filteredIndex;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() {
            _selectedIndex = isSelected ? null : filteredIndex;
          });
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      leave.leaveType,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _heading,
                      ),
                    ),
                  ),
                  _statusPill(leave.status), // 🔁 live status pill
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _labelValue("Dates", "${leave.startDate} - ${leave.endDate}"),
                  _labelValue("Days Taken", _daysText(leave.totalDays)),
                ],
              ),
              _managerComment(leave.reason),

              if (isSelected) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: _border),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE11D48)),
                      foregroundColor: const Color(0xFFE11D48),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _confirmAndCancel(leave, filteredIndex),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only this user's leaves
    final visible = myLeaves.where((lv) => lv.employeeId == widget.user.id).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.home_outlined, color: _brandBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Leaves",
          style: TextStyle(color: _heading, fontWeight: FontWeight.w700),
        ),
      ),
      body: visible.isEmpty
          ? const Center(
              child: Text("No leave applications submitted yet.", style: TextStyle(color: _muted)),
            )
          : ListView.builder(
              itemCount: visible.length,
              padding: const EdgeInsets.only(bottom: 16),
              itemBuilder: (context, index) {
                final leave = visible[index];
                return _cardForLeave(leave, index);
              },
            ),
    );
  }
}
