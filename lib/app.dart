import 'package:flutter/material.dart';

import 'screens/auth_gate.dart';
import 'screens/firebase_setup_screen.dart';
import 'theme/app_theme.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

class GroceryTrackerApp extends StatelessWidget {
  const GroceryTrackerApp({super.key, this.firebaseError});

  final Object? firebaseError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'GroPanda',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: firebaseError == null
          ? const AuthGate()
          : FirebaseSetupScreen(firebaseError: firebaseError),
    );
  }
}
