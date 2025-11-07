import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class User {
  final String id;
  final String name;
  final String gender;
  final String department;
  final String position;
  final String contactNumber;
  String password;
  bool firstLogin;

  User({
    required this.id,
    required this.name,
    required this.gender,
    required this.department,
    required this.position,
    required this.contactNumber,
    required this.password,
    this.firstLogin = true,
  });
}

class UserStorage {
  static List<User> users = [];

  // Load users from CSV
  static Future<void> loadUsers() async {
    final csvData = await rootBundle.loadString('assets/employees.csv');
    final lines = const LineSplitter().convert(csvData);

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final values = line.split(',');
      if (values.length < 6) continue;

      users.add(User(
        id: values[0],
        name: values[1],
        gender: values[2],
        department: values[3],
        position: values[4],
        contactNumber: values[5],
        password: values[0], // default password = employee ID
      ));
    }
  }

  static User? findUser(String input) {
    try {
      return users.firstWhere(
        (u) => u.id == input || u.name.toLowerCase() == input.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  static void updatePassword(User user, String newPassword) {
    user.password = newPassword;
    user.firstLogin = false;
  }
}
