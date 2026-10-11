import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/playful_entrance.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'username_setup_screen.dart';
import 'welcome_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen();
        }

        if (snapshot.hasError) {
          return LoginScreen(
            initialError:
                'We could not check your login session. Please sign in again.',
            authService: authService,
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return WelcomeScreen(authService: authService);
        }

        return FutureBuilder<Map<String, dynamic>>(
          future: authService.getProfile(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const _AuthLoadingScreen();
            }
            if (profileSnapshot.hasError) {
              return LoginScreen(
                initialError:
                    'We could not load your profile. Please try again.',
                authService: authService,
              );
            }
            final profile = profileSnapshot.data ?? {};
            if ((profile['username'] as String?)?.trim().isEmpty != false) {
              return UsernameSetupScreen(authService: authService, user: user);
            }
            return MainShell(authService: authService, user: user);
          },
        );
      },
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGreenBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MascotFloat(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Image.asset(
                    'assets/images/gropanda_logo.png',
                    width: 168,
                    height: 168,
                    fit: BoxFit.cover,
                    semanticLabel: 'GroPanda panda with a grocery basket',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'GroPanda',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.darkGreen,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Getting your pantry ready…',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              const SizedBox.square(
                dimension: 26,
                child: CircularProgressIndicator(
                  color: AppColors.darkGreen,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
