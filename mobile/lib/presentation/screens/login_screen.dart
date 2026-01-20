import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../themes/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/auth_state.dart';

/// OTP Login Screen
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkDevMode();
  }

  void _checkDevMode() {
    // We can rely on provider state for devMode if we want, or keep local check.
    // However, the provider now has devMode in state, so let's use that if possible.
    // For now, let's just trigger a session check which loads config.
    ref.read(authProvider.notifier).checkSession();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();
    // Basic validation, more can be done in provider or service
    if (phone.isEmpty || phone.length < 10) {
      // We can set error in provider or show local snackbar.
      // Since we want to move logic, let's just call provider, but provider expects valid input?
      // Let's keep simple validation here for UI feedback speed.
      // actually, let's invoke provider and let it handle or just do basic check here.
      // But we can't set error in provider easily without a method.
      // Let's just do it.
    }

    await ref.read(authProvider.notifier).sendOTP(phone);
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    final phone = _phoneController.text.trim();
    await ref.read(authProvider.notifier).verifyOTP(phone, otp);
  }

  void _listenToAuthChanges(AuthState? previous, AuthState next) {
    if (next.status == AuthStatus.authenticated) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }

    // Auto-fill for dev mode
    if (next.devMode &&
        next.otpSent == false &&
        _phoneController.text.isEmpty) {
      _phoneController.text = '+13001234572';
    }

    if (next.otpSent && next.devMode && _otpController.text.isEmpty) {
      _otpController.text = '123456';
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, _listenToAuthChanges);
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor.withOpacity(0.1),
              AppTheme.surfaceColor,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // Logo
                Icon(
                  Icons.local_shipping,
                  size: 80,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),

                // Title
                const DualLanguageText(
                  primaryText: 'Welcome to TruckMate',
                  subtitleText: 'ਟਰੱਕਮੇਟ ਵਿੱਚ ਜੀ ਆਇਆਂ ਨੂੰ',
                  primaryStyle: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  alignment: CrossAxisAlignment.center,
                ),
                const SizedBox(height: 40),

                // Dev mode indicator
                if (authState.devMode)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.warningColor),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.build,
                          color: AppTheme.warningColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Development Mode - OTP: 123456',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),

                // Phone Input
                if (!authState.otpSent) ...[
                  _buildLabel('Phone Number', 'ਫ਼ੋਨ ਨੰਬਰ'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[\d+\-\s\(\)]'),
                      ),
                    ],
                    decoration: InputDecoration(
                      hintText: '+1 (555) 123-4567',
                      prefixIcon: const Icon(Icons.phone),
                      errorText: authState.errorMessage,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: authState.isLoading ? null : _sendOTP,
                    style: AppTheme.actionButtonStyle,
                    child: authState.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const DualLanguageText(
                            primaryText: 'Send OTP',
                            subtitleText: 'OTP ਭੇਜੋ',
                            alignment: CrossAxisAlignment.center,
                            primaryStyle: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                            subtitleStyle:
                                TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                  ),
                ],

                // OTP Input
                if (authState.otpSent) ...[
                  _buildLabel('Enter OTP', 'OTP ਦਾਖਲ ਕਰੋ'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(
                      fontSize: 32,
                      letterSpacing: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      counterText: '',
                      errorText: authState.errorMessage,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: authState.isLoading ? null : _verifyOTP,
                    style: AppTheme.actionButtonStyle,
                    child: authState.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const DualLanguageText(
                            primaryText: 'Verify & Login',
                            subtitleText: 'ਪੁਸ਼ਟੀ ਕਰੋ ਅਤੇ ਲੌਗਇਨ ਕਰੋ',
                            alignment: CrossAxisAlignment.center,
                            primaryStyle: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                            subtitleStyle:
                                TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      ref.read(authProvider.notifier).changePhoneNumber();
                      _otpController.clear();
                    },
                    child: const DualLanguageText(
                      primaryText: 'Change Phone Number',
                      subtitleText: 'ਫ਼ੋਨ ਨੰਬਰ ਬਦਲੋ',
                      alignment: CrossAxisAlignment.center,
                      primaryStyle: TextStyle(color: AppTheme.primaryColor),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String primary, String subtitle) {
    return DualLanguageText(
      primaryText: primary,
      subtitleText: subtitle,
      primaryStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }
}
