import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key, this.firebaseError});

  final Object? firebaseError;

  bool get _isConfigured => firebaseError == null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.lightGreenBackground,
                AppColors.secondaryBackground,
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 86,
                          height: 86,
                          decoration: const BoxDecoration(
                            color: AppColors.lightGreenBackground,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.local_grocery_store_rounded,
                            color: AppColors.primaryGreen,
                            size: 46,
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Grocery Tracker',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.darkGreen,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isConfigured
                              ? 'Firebase is initialized and ready for authentication.'
                              : 'Firebase configuration is needed before authentication can start.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _StatusPanel(isConfigured: _isConfigured),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('Login screen starts in Phase 3'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.isConfigured});

  final bool isConfigured;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConfigured ? AppColors.secondaryBackground : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderGreen),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isConfigured
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            color: isConfigured ? AppColors.primaryGreen : AppColors.darkGreen,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isConfigured
                  ? 'Phase 1 and Phase 2 foundation is ready.'
                  : 'Run FlutterFire configuration to generate Firebase options and platform files.',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
