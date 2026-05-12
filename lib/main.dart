import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'login_screen.dart';
import 'employee_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // =========================
    // INITIALIZE FIREBASE
    // =========================
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    print('FIREBASE INITIALIZED SUCCESSFULLY');

    // =========================
    // TEST FIRESTORE CONNECTION
    // =========================
    final ref = await FirebaseFirestore.instance
        .collection('test_collection')
        .add({
      'message': 'Firestore connection successful',
      'createdAt': FieldValue.serverTimestamp(),
    });

    print('TEST DOCUMENT CREATED');
    print('DOC ID: ${ref.id}');

  } catch (e) {
    print('FIREBASE INITIALIZATION ERROR');
    print(e);
  }

  // =========================
  // LOAD EMPLOYEE DATA
  // =========================
  loadEmployees();

  // =========================
  // START APP
  // =========================
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Leave Management System',

      home: const LoginScreen(),

      routes: {
        '/loginFailed': (_) => const LoginFailedScreen(),
      },
    );
  }
}

class LoginFailedScreen extends StatelessWidget {
  const LoginFailedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Failed'),
      ),

      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const LoginScreen(),
              ),
            );
          },

          child: const Text('Try Again'),
        ),
      ),
    );
  }
}