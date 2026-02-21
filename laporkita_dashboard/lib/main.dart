// File: app/laporkita_dashboard/lib/main.dart
// This is the entry point of your Flutter app — like index.js for Node.js

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Firebase initialization
import 'package:firebase_auth/firebase_auth.dart'; // Authentication
import 'firebase_options.dart'; // Auto-generated Firebase config
import 'screens/login_screen.dart'; // Login page
import 'screens/dashboard_screen.dart'; // Main dashboard

// main() is the entry point — Flutter calls this first
void main() async {
  // Ensure Flutter widgets are initialized before Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with the config from firebase_options.dart
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Run the app
  runApp(const LaporKitaApp());
}

// Root widget of the app
class LaporKitaApp extends StatelessWidget {
  const LaporKitaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LaporKita AI Dashboard',

      // App-wide theme (colors, fonts)
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(
            0xFF1565C0,
          ), // Dark blue (Malaysian flag-inspired)
          brightness: Brightness.light,
        ),
        useMaterial3: true, // Use Material Design 3
        fontFamily: 'Roboto',
      ),

      debugShowCheckedModeBanner: false, // Remove "debug" banner in top-right
      // AuthWrapper decides whether to show Login or Dashboard
      home: const AuthWrapper(),
    );
  }
}

// AuthWrapper checks if user is logged in and shows appropriate screen
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder listens to auth state changes
    // When user logs in/out, this automatically updates the UI
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still checking auth state (loading)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(), // Loading spinner
            ),
          );
        }

        // User is logged in — show Dashboard
        if (snapshot.hasData && snapshot.data != null) {
          return const DashboardScreen();
        }

        // User is NOT logged in — show Login
        return const LoginScreen();
      },
    );
  }
}
