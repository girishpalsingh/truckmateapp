import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../themes/app_theme.dart';
import '../../services/auth_service.dart';
import '../../config/app_config.dart';

/// OTP Login Screen
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _authService = AuthService();

  bool _otpSent = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _devMode = false;

  @override
  void initState() {
    super.initState();
    _checkDevMode();
  }

  void _checkDevMode() async {
    final config = await AppConfig.load();
    if (config.isDevelopment && mounted) {
      setState(() {
        _devMode = true;
        _phoneController.text = '+1234567890';
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      setState(() => _errorMessage = 'Please enter a valid phone number');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.sendOTP(phoneNumber: phone);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success) {
          _otpSent = true;
          if (result.devMode) {
            _otpController.text = '123456';
          }
        } else {
          _errorMessage = result.message;
        }
      });
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter a 6-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.verifyOTP(
      phoneNumber: _phoneController.text.trim(),
      otp: otp,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (result.success) {
        if (result.userExists) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        } else {
          // TODO: Navigate to registration
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } else {
        setState(() => _errorMessage = result.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                if (_devMode)
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
                if (!_otpSent) ...[
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
                      errorText: _errorMessage,
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendOTP,
                    style: AppTheme.actionButtonStyle,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const DualLanguageText(
                            primaryText: 'Send OTP',
                            subtitleText: 'OTP ਭੇਜੋ',
                            alignment: CrossAxisAlignment.center,
                          ),
                  ),
                ],

                // OTP Input
                if (_otpSent) ...[
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
                      errorText: _errorMessage,
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOTP,
                    style: AppTheme.actionButtonStyle,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const DualLanguageText(
                            primaryText: 'Verify & Login',
                            subtitleText: 'ਪੁਸ਼ਟੀ ਕਰੋ ਅਤੇ ਲੌਗਇਨ ਕਰੋ',
                            alignment: CrossAxisAlignment.center,
                          ),
                  ),
                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () {
                      setState(() {
                        _otpSent = false;
                        _otpController.clear();
                        _errorMessage = null;
                      });
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
