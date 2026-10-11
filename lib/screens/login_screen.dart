import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/playful_entrance.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authService,
    this.initialError,
    this.initialSignUp = false,
    this.onBack,
  });

  final AuthService authService;
  final String? initialError;
  final bool initialSignUp;
  final VoidCallback? onBack;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSignUp = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.initialError;
    _isSignUp = widget.initialSignUp;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignUp) {
        await widget.authService.createAccountWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await widget.authService.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = widget.authService.friendlyAuthError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await widget.authService.signInWithGoogle();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = widget.authService.friendlyAuthError(error);
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(
        () =>
            _errorMessage = 'Enter your email above, then tap Forgot Password?',
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await widget.authService.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Please check your inbox.'),
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = widget.authService.friendlyAuthError(error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleMode(bool signUp) {
    setState(() {
      _isSignUp = signUp;
      _errorMessage = null;
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
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
                    padding: const EdgeInsets.all(26),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.onBack != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                tooltip: 'Back',
                                onPressed: widget.onBack,
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                            ),
                          _LoginHeader(isSignUp: _isSignUp),
                          const SizedBox(height: 24),
                          _AuthToggle(
                            isSignUp: _isSignUp,
                            onChanged: _toggleMode,
                          ),
                          const SizedBox(height: 22),
                          if (!_isSignUp) ...[
                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : _googleSignIn,
                              icon: _isLoading
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.g_mobiledata_rounded),
                              label: Text(
                                _isLoading
                                    ? 'Connecting to Google...'
                                    : 'Continue with Google',
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                'or',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                          CustomTextField(
                            controller: _emailController,
                            label: 'Email',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.email_outlined,
                            validator: _validateEmail,
                          ),
                          if (!_isSignUp)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoading ? null : _forgotPassword,
                                child: const Text('Forgot Password?'),
                              ),
                            ),
                          const SizedBox(height: 14),
                          CustomTextField(
                            controller: _passwordController,
                            label: 'Password',
                            obscureText: !_isPasswordVisible,
                            prefixIcon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              tooltip: _isPasswordVisible
                                  ? 'Hide password'
                                  : 'Show password',
                              onPressed: () => setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              }),
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                            validator: _validatePassword,
                          ),
                          if (_isSignUp) ...[
                            const SizedBox(height: 14),
                            CustomTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm Password',
                              obscureText: !_isConfirmPasswordVisible,
                              prefixIcon: Icons.lock_reset_rounded,
                              suffixIcon: IconButton(
                                tooltip: _isConfirmPasswordVisible
                                    ? 'Hide password'
                                    : 'Show password',
                                onPressed: () => setState(() {
                                  _isConfirmPasswordVisible =
                                      !_isConfirmPasswordVisible;
                                }),
                                icon: Icon(
                                  _isConfirmPasswordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                              validator: _validateConfirmPassword,
                            ),
                          ],
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            _ErrorMessage(message: _errorMessage!),
                          ],
                          const SizedBox(height: 22),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(_isSignUp ? 'Create Account' : 'Log In'),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => _toggleMode(!_isSignUp),
                            child: Text(
                              _isSignUp
                                  ? 'Already have an account? Log In'
                                  : "Don't have an account? Sign Up",
                            ),
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
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Email is required.';
    }
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Password is required.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (!_isSignUp) {
      return null;
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader({required this.isSignUp});
  final bool isSignUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MascotFloat(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/images/gropanda_logo.png',
              width: 88,
              height: 88,
              fit: BoxFit.cover,
              semanticLabel: 'GroPanda panda grocery logo',
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          isSignUp ? 'Create Your Account' : 'Welcome Back!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.darkGreen,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isSignUp
              ? 'Start keeping track of your groceries today!'
              : 'Log in to continue',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _AuthToggle extends StatelessWidget {
  const _AuthToggle({required this.isSignUp, required this.onChanged});

  final bool isSignUp;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleButton(
              label: 'Login',
              isSelected: !isSignUp,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _ToggleButton(
              label: 'Sign Up',
              isSelected: isSignUp,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? AppColors.darkGreen : AppColors.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFB91C1C),
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }
}
