// apply_for_leave_screen.dart
import 'package:flutter/material.dart';

import 'employee_data.dart';
import 'leave_data.dart';
import 'notification_data.dart';
import 'leave_balance_data.dart';

// Firestore write helper
import 'fire_backend.dart';

// Keep picking files exactly like before (we won't upload them here)
import 'package:file_picker/file_picker.dart';

class ApplyLeaveScreen extends StatefulWidget {
  final Employee user;

  const ApplyLeaveScreen({super.key, required this.user});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  String? leaveType;
  DateTime? startDate;
  DateTime? endDate;
  String reason = "";

  late final TextEditingController startDateController;
  late final TextEditingController endDateController;
  late final TextEditingController totalDaysController;

  // Supporting document (pick only; no upload)
  PlatformFile? _pickedFile;
  String? _pickedFileName; // we keep the filename for Firestore metadata only

  // Progress state (we keep your submitting state so the button shows a spinner)
  bool _submitting = false;

  // Which leave types must have a supporting document
  final Set<String> _docRequiredTypes = {
    "Sick Leave",
    "Maternity Leave",
    "Parental Leave",
    "Adoption Leave",
    "Commissioning Parental Leave",
  };

  @override
  void initState() {
    super.initState();
    startDateController = TextEditingController();
    endDateController = TextEditingController();
    totalDaysController = TextEditingController(text: '0');
    ensureBalancesForUser(widget.user.id);
  }

  @override
  void dispose() {
    startDateController.dispose();
    endDateController.dispose();
    totalDaysController.dispose();
    super.dispose();
  }

  // Keep your exact options
  final List<String> leaveTypes = [
    "Annual Leave",
    "Sick Leave",
    "Maternity Leave",
    "Parental Leave",
    "Adoption Leave",
    "Commissioning Parental Leave",
    "Family Responsibility",
    "Special Leave",
    "Unpaid Leave",
  ];

  final List<DateTime> publicHolidays = [
    DateTime(2025, 1, 1),
    DateTime(2025, 3, 21),
    DateTime(2025, 4, 18),
    DateTime(2025, 4, 21),
    DateTime(2025, 4, 27),
    DateTime(2025, 5, 1),
    DateTime(2025, 6, 16),
    DateTime(2025, 8, 9),
    DateTime(2025, 9, 24),
    DateTime(2025, 12, 16),
    DateTime(2025, 12, 25),
    DateTime(2025, 12, 26),
  ];

  static const _brandBlue = Color(0xFF3B4D79);
  static const _heading   = Color(0xFF111827);
  static const _muted     = Color(0xFF6B7280);
  static const _border    = Color(0xFFE5E7EB);

  InputDecoration _dec(String label, {IconData? icon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: _muted, fontWeight: FontWeight.w600),
      prefixIcon: icon == null ? null : Icon(icon, color: _brandBlue),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _brandBlue, width: 1.2),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 0.6,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: _heading)),
            const SizedBox(height: 12),
            const Divider(height: 1, color: _border),
            const SizedBox(height: 12),
            child
          ],
        ),
      ),
    );
  }

  bool _isWeekend(DateTime d) =>
      d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

  bool _isPublicHoliday(DateTime d) =>
      publicHolidays.any((h) => h.year == d.year && h.month == d.month && h.day == d.day);

  String _prettyDate(DateTime d) {
    const months = ['jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec'];
    final day = d.day;
    String suffix = 'th';
    if (!(day >= 11 && day <= 13)) {
      switch (day % 10) {
        case 1: suffix = 'st'; break;
        case 2: suffix = 'nd'; break;
        case 3: suffix = 'rd'; break;
      }
    }
    return "${months[d.month - 1]}  $day$suffix, ${d.year}";
  }

  void _refreshVisibleFields() {
    startDateController.text = startDate == null ? '' : _prettyDate(startDate!);
    endDateController.text = endDate == null ? '' : _prettyDate(endDate!);
    totalDaysController.text = calculateTotalDays().toString();
  }

  Future<void> pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? (startDate ?? DateTime.now()) : (endDate ?? startDate ?? DateTime.now())),
      firstDate: DateTime.now(),
      lastDate: DateTime(2026, 12, 31),
    );

    if (!mounted) return;

    if (picked != null) {
      if (_isWeekend(picked)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You cannot select a weekend.")),
        );
        return;
      }

      if (_isPublicHoliday(picked)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You cannot select a public holiday.")),
        );
        return;
      }

      if (!isStart && startDate != null && picked.isBefore(startDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("End date cannot be before start date.")),
        );
        return;
      }

      setState(() {
        if (isStart) {
          startDate = picked;
          if (endDate != null && endDate!.isBefore(startDate!)) {
            endDate = null;
          }
        } else {
          endDate = picked;
        }
        _refreshVisibleFields();
      });
    }
  }

  int calculateTotalDays() {
    if (startDate == null || endDate == null) return 0;

    int count = 0;
    var current = DateTime(startDate!.year, startDate!.month, startDate!.day);
    final last = DateTime(endDate!.year, endDate!.month, endDate!.day);

    while (!current.isAfter(last)) {
      if (!_isWeekend(current) && !_isPublicHoliday(current)) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  // Pick a supporting document (no upload)
  Future<void> _pickSupportingDoc() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: false, // not uploading, so we don't need bytes
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() {
        _pickedFile = res.files.first;
        _pickedFileName = _pickedFile?.name;
      });
    }
  }

  void _clearSupportingDoc() {
    setState(() {
      _pickedFile = null;
      _pickedFileName = null;
    });
  }

  Future<void> submitForm() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    if (_formKey.currentState!.validate()) {
      if (startDate == null || endDate == null) {
        messenger
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text("Please select both start and end dates.")));
        return;
      }
      if (leaveType == null) {
        messenger
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text("Please select leave type.")));
        return;
      }

      // If this leave requires a document, only enforce that a file was PICKED
      if (_docRequiredTypes.contains(leaveType!) && _pickedFile == null) {
        messenger
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text("Supporting document is required for $leaveType.")));
        return;
      }

      final days = calculateTotalDays();
      if (days <= 0) {
        messenger
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text("No working days in the selected range.")));
        return;
      }

      setState(() => _submitting = true);

      try {
        // Deduct balance
        final ok = deductBalance(
          employeeId: widget.user.id,
          leaveType: leaveType!,
          days: days,
        );
        if (!ok) {
          messenger
            ..clearSnackBars()
            ..showSnackBar(const SnackBar(content: Text("Insufficient balance for this leave type.")));
          return;
        }

        // Create local pending leave (no upload — only store filename)
        final newLeave = LeaveApplication(
          employeeName: widget.user.name,
          employeeId: widget.user.id,
          department: widget.user.department,
          leaveType: leaveType!,
          startDate: "${startDate!.day}/${startDate!.month}/${startDate!.year}",
          endDate: "${endDate!.day}/${endDate!.month}/${endDate!.year}",
          totalDays: days,
          reason: reason,
          status: "pending",
          attachmentUrl: null,               // not uploading
          attachmentName: _pickedFileName,   // filename only
        );

        myLeaves.add(newLeave);
        final localIndex = myLeaves.length - 1;

        // ONE self notification (mobile)
        myNotifications.add(
          NotificationModel(
            title: "Leave Application Submitted",
            message:
                "You applied for $leaveType from ${newLeave.startDate} to ${newLeave.endDate} (${newLeave.totalDays} day${days == 1 ? '' : 's'}).",
            timestamp: DateTime.now(),
            employeeId: widget.user.id,
          ),
        );

        messenger
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text("Submitting...")));

        // Firestore: send request + metadata (NO FILE)
        final docId = await createLeaveRequest(
          employeeId: widget.user.id,
          employeeName: widget.user.name,
          department: widget.user.department,
          leaveType: leaveType!,
          totalDays: days,
          startDateIso: startDate!.toIso8601String(),
          endDateIso: endDate!.toIso8601String(),
          startDateText: newLeave.startDate,
          endDateText: newLeave.endDate,
          reason: reason,
          attachmentUrl: null,              // keep existing param for compatibility
          attachmentName: _pickedFileName,  // filename only
        );

        if (docId.isNotEmpty && localIndex >= 0 && localIndex < myLeaves.length) {
          myLeaves[localIndex] = myLeaves[localIndex].copyWith(
            firebaseId: docId,
            status: "pending",
            attachmentUrl: null,
            attachmentName: _pickedFileName,
          );
        }

        if (!mounted) return;
        messenger
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text("Leave request submitted! Balance updated.")));
        Navigator.of(context).pop();
      } catch (e) {
        debugPrint('Submit failed: $e');
        if (!mounted) return;
        messenger
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text("Could not submit: $e")));
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          "Application Details",
          style: TextStyle(color: _heading, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.home, color: _brandBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _sectionCard(
                title: "Employee Name",
                child: TextFormField(
                  initialValue: u.name,
                  readOnly: true,
                  decoration: _dec("Employee Name", icon: Icons.person_outline),
                ),
              ),
              _sectionCard(
                title: "Employee ID",
                child: TextFormField(
                  initialValue: u.id,
                  readOnly: true,
                  decoration: _dec("Employee ID", icon: Icons.badge_outlined),
                ),
              ),
              _sectionCard(
                title: "Department",
                child: TextFormField(
                  initialValue: u.department,
                  readOnly: true,
                  decoration: _dec("Department", icon: Icons.apartment_outlined),
                ),
              ),
              _sectionCard(
                title: "Type of Leave",
                child: DropdownButtonFormField<String>(
                  value: leaveType,
                  decoration: _dec("Select Leave Type", icon: Icons.event_note_outlined),
                  items: leaveTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => leaveType = v),
                  validator: (v) => v == null ? "Please select leave type" : null,
                ),
              ),
              _sectionCard(
                title: "Start Date",
                child: TextFormField(
                  controller: startDateController,
                  readOnly: true,
                  keyboardType: TextInputType.none,
                  onTap: () => pickDate(isStart: true),
                  decoration: _dec("Start Date", icon: Icons.calendar_today_outlined),
                ),
              ),
              _sectionCard(
                title: "End Date",
                child: TextFormField(
                  controller: endDateController,
                  readOnly: true,
                  keyboardType: TextInputType.none,
                  onTap: () => pickDate(isStart: false),
                  decoration: _dec("End Date", icon: Icons.calendar_month_outlined),
                ),
              ),
              _sectionCard(
                title: "Total Days Requested",
                child: TextFormField(
                  controller: totalDaysController,
                  enabled: false,
                  decoration: _dec("Total Days"),
                ),
              ),
              _sectionCard(
                title: "Reason",
                child: TextFormField(
                  maxLines: 3,
                  onChanged: (val) => reason = val,
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? "Enter reason" : null,
                  decoration: _dec("Provide a brief reason", icon: Icons.notes_outlined),
                ),
              ),

              // Supporting Document section (unchanged UI; just stores filename)
              _sectionCard(
                title: "Supporting Document",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Attach a PDF or image. "
                      "${(leaveType != null && _docRequiredTypes.contains(leaveType!)) ? "(Required for $leaveType)" : "(Optional)"}",
                      style: const TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _submitting ? null : _pickSupportingDoc,
                          icon: const Icon(Icons.attach_file),
                          label: const Text("Attach file"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _brandBlue,
                            side: const BorderSide(color: _border),
                            elevation: 0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_pickedFileName != null)
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Icon(Icons.insert_drive_file_outlined, color: _brandBlue, size: 18),
                                Text(_pickedFileName!, overflow: TextOverflow.ellipsis),
                                IconButton(
                                  onPressed: _submitting ? null : _clearSupportingDoc,
                                  icon: const Icon(Icons.close, size: 18),
                                  tooltip: "Remove file",
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              "Submitting...",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          "Submit Application",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
