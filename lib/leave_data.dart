class LeaveApplication {
  String employeeName;
  String employeeId;
  String department;
  String leaveType;
  String startDate;
  String endDate;
  int totalDays;
  String reason;

  /// ✅ Added for Firebase document reference
  String? firebaseId;

  /// ✅ Track status: pending / approved / rejected / cancelled
  String status;

  /// ✅ NEW: optional supporting document fields
  String? attachmentUrl;
  String? attachmentName;

  LeaveApplication({
    required this.employeeName,
    required this.employeeId,
    required this.department,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.reason,
    this.firebaseId,
    this.status = "pending",  // default = pending
    this.attachmentUrl,       // NEW
    this.attachmentName,      // NEW
  });

  /// ✅ Converts the LeaveApplication to Firestore JSON
  Map<String, dynamic> toJson() {
    return {
      "employeeName": employeeName,
      "employeeId": employeeId,
      "department": department,
      "leaveType": leaveType,
      "startDate": startDate,
      "endDate": endDate,
      "totalDays": totalDays,
      "reason": reason,
      "status": status,
      "firebaseId": firebaseId,
      "createdAt": DateTime.now().toIso8601String(),

      // NEW: only include when present
      if (attachmentUrl != null) "attachmentUrl": attachmentUrl,
      if (attachmentName != null) "attachmentName": attachmentName,
    };
  }

  /// ✅ Create LeaveApplication from Firestore
  factory LeaveApplication.fromJson(Map<String, dynamic> json, String id) {
    return LeaveApplication(
      employeeName: json["employeeName"],
      employeeId: json["employeeId"],
      department: json["department"],
      leaveType: json["leaveType"],
      startDate: json["startDate"],
      endDate: json["endDate"],
      totalDays: json["totalDays"],
      reason: json["reason"],
      status: json["status"] ?? "pending",
      firebaseId: id,

      // NEW
      attachmentUrl: json["attachmentUrl"],
      attachmentName: json["attachmentName"],
    );
  }

  /// ✅ Copy method (used to attach firebaseId later)
  LeaveApplication copyWith({
    String? firebaseId,
    String? status,
    String? attachmentUrl,   // NEW
    String? attachmentName,  // NEW
  }) {
    return LeaveApplication(
      employeeName: employeeName,
      employeeId: employeeId,
      department: department,
      leaveType: leaveType,
      startDate: startDate,
      endDate: endDate,
      totalDays: totalDays,
      reason: reason,
      firebaseId: firebaseId ?? this.firebaseId,
      status: status ?? this.status,

      // NEW
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentName: attachmentName ?? this.attachmentName,
    );
  }

  /// ✅ Convenience
  bool get hasAttachment => (attachmentUrl != null && attachmentUrl!.isNotEmpty);
}

/// ✅ Global Leave List
List<LeaveApplication> myLeaves = [];

/// ✅ Helper to filter leaves by employee
List<LeaveApplication> leavesFor(String employeeId) =>
    myLeaves.where((lv) => lv.employeeId == employeeId).toList();
