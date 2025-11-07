import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'login_screen.dart';
import 'employee_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Try to initialize Firebase on whatever platform we're running.
  // If this platform wasn't configured in firebase_options.dart, we just continue.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // On Windows/macOS (not configured), this will throw an UnsupportedError — that's fine.
    // You can still run the app; Firestore calls just won't work on those targets.
    // When you run on Android or Chrome (web), Firebase will be initialized correctly.
    // debugPrint('Firebase init skipped: $e');
  }

  loadEmployees(); // your dataset for login
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WIL Leave System',
      home: const LoginScreen(),
      routes: {'/loginFailed': (_) => const LoginFailedScreen()},
    );
  }
}

class LoginFailedScreen extends StatelessWidget {
  const LoginFailedScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Login Failed')),
    body: Center(
      child: ElevatedButton(
        onPressed: () => Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen())),
        child: const Text('Try Again'),
      ),
    ),
  );
}
