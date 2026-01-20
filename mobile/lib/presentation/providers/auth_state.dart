import '../../data/models/user_profile.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
}

class AuthState {
  final AuthStatus status;
  final bool isLoading;
  final bool otpSent;
  final String? errorMessage;
  final UserProfile? userProfile;
  final bool devMode;

  const AuthState({
    this.status = AuthStatus.initial,
    this.isLoading = false,
    this.otpSent = false,
    this.errorMessage,
    this.userProfile,
    this.devMode = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    bool? isLoading,
    bool? otpSent,
    String? errorMessage,
    UserProfile? userProfile,
    bool? devMode,
  }) {
    return AuthState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      otpSent: otpSent ?? this.otpSent,
      errorMessage:
          errorMessage, // creating a new state often clears the error, so default to null if not provided
      userProfile: userProfile ?? this.userProfile,
      devMode: devMode ?? this.devMode,
    );
  }
}
