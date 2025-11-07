import 'package:flutter/material.dart';
import 'login_screen.dart';

class LoginFailedScreen extends StatelessWidget {
  const LoginFailedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ❌ Red circle with X
                Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Color(0xFFB0413E),
                      width: 6,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.close,
                      color: Color(0xFFB0413E),
                      size: 70,
                    ),
                  ),
                ),

                const SizedBox(height: 35),

                // 🔴 Title text
                const Text(
                  "Login Unsuccessful",
                  style: TextStyle(
                    fontSize: 22,
                    color: Color(0xFFB0413E),
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 20),

                // 📄 Description text
                const Text(
                  "It seems there was an issue with your credentials. "
                  "Please double-check your username and password, then try again.\n\n"
                  "If the problem persists, you can reset your password or contact support.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.5,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 45),

                // 🔁 Retry login button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3B4D79),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Retry Login",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
