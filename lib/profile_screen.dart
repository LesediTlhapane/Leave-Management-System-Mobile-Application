import 'package:flutter/material.dart';
import 'employee_data.dart'; // Employee class

class ProfileScreen extends StatefulWidget {
  final Employee user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController emailController;
  late TextEditingController contactController;

  // ------- Styles & Colors -------
  static const _brandBlue = Color(0xFF3B4D79);
  static const _mutedText = Color(0xFF6B7280); // gray-500
  static const _headingText = Color(0xFF111827); // gray-900
  static const _cardBorder = Color(0xFFE5E7EB); // gray-200
  static const _chipBg = Color(0xFFF3F4F6);

  TextStyle get _sectionTitleStyle => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: _headingText,
      );

  TextStyle get _labelStyle => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _mutedText,
      );

  TextStyle get _valueStyle => const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: _headingText,
      );

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController(text: widget.user.email);
    contactController = TextEditingController(text: widget.user.contactNumber);
  }

  @override
  void dispose() {
    emailController.dispose();
    contactController.dispose();
    super.dispose();
  }

  void saveProfile() {
    setState(() {
      widget.user.email = emailController.text.trim();
      widget.user.contactNumber = contactController.text.trim();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile updated successfully!")),
    );
  }

  // -------- UI helpers ----------
  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _chipBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: _brandBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: _labelStyle),
                  const SizedBox(height: 4),
                  Text(value, style: _valueStyle),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: _cardBorder),
        const SizedBox(height: 12),
      ],
    );
  }

  InputDecoration _editDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: _labelStyle,
      prefixIcon: Icon(icon, color: _brandBlue),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _brandBlue, width: 1.4),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _cardBorder),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
     appBar: AppBar(
  centerTitle: true,
  elevation: 0,
  backgroundColor: Colors.white,
  surfaceTintColor: Colors.white,
  title: const Text(
    "Employee Profile",
    style: TextStyle(
      color: Color(0xFF111827), // _headingText
      fontWeight: FontWeight.w700,
    ),
  ),
  leading: IconButton(
    icon: const Icon(Icons.home_outlined, color: Color(0xFF3B4D79)), // _brandBlue
    onPressed: () => Navigator.pop(context),
  ),
  // 🔻 Removed the actions (logout icon)
  // actions: const [
  //   Padding(
  //     padding: EdgeInsets.only(right: 8),
  //     child: Icon(Icons.login_outlined, color: _brandBlue),
  //   )
  // ],
),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Profile header card ----
              _card(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: _brandBlue,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : "U",
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _headingText,
                              )),
                          const SizedBox(height: 4),
                          Text(
                            user.position,
                            style: const TextStyle(
                              color: _mutedText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ---- Employee Information ----
              Text("Employee Information", style: _sectionTitleStyle),
              const SizedBox(height: 10),
              _card(
                child: Column(
                  children: [
                    _infoRow(
                      icon: Icons.badge_outlined,
                      label: "Employee ID",
                      value: user.id,
                    ),
                    _infoRow(
                      icon: Icons.apartment_outlined,
                      label: "Department",
                      value: user.department,
                    ),
                    // last row without bottom divider
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _chipBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.work_outline,
                              size: 18, color: _brandBlue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Position", style: _labelStyle),
                              const SizedBox(height: 4),
                              Text(user.position, style: _valueStyle),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ---- Contact Information (editable) ----
              Text("Contact Information", style: _sectionTitleStyle),
              const SizedBox(height: 10),
              _card(
                child: Column(
    children: [
      TextField(
        controller: emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: _editDecoration("Email", Icons.mail_outline),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: contactController,
        keyboardType: TextInputType.phone,
        decoration: _editDecoration("Phone", Icons.call_outlined),
      ),
    ],
  ),
),

              const SizedBox(height: 8),

              // ---- Save button ----
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Save Changes",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
