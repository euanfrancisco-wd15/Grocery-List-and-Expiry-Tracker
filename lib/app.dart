import 'package:flutter/material.dart';

import 'screens/auth_gate.dart';
import 'screens/firebase_setup_screen.dart';
import 'theme/app_theme.dart';

class GroceryTrackerApp extends StatelessWidget {
  const GroceryTrackerApp({super.key, this.firebaseError});

  final Object? firebaseError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grocery Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: firebaseError == null
          ? const AuthGate()
          : FirebaseSetupScreen(firebaseError: firebaseError),
    );
  }
}
