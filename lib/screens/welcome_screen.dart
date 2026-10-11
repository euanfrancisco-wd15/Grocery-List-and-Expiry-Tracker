import 'package:flutter/material.dart';


import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _showAuth = false;
  bool _signUp = false;

  @override
  Widget build(BuildContext context) {
    if (_showAuth) {
      return LoginScreen(
        authService: widget.authService,
        initialSignUp: _signUp,
        onBack: () => setState(() => _showAuth = false),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/images/gropanda_logo.png',
                      width: 210,
                      height: 210,
                      fit: BoxFit.cover,
                      semanticLabel: 'GroPanda panda grocery logo',
                    ),
                  ),
                  const SizedBox(height: 34),
                  Text(
                    'GroPanda',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.darkGreen,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Keep track. Eat fresh. Save more.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 38),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => setState(() {
                        _signUp = true;
                        _showAuth = true;
                      }),
                      child: const Text('Get Started'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() {
                      _signUp = false;
                      _showAuth = true;
                    }),
                    child: const Text('Already have an account? Log In'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
