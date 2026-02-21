import 'package:equatable/equatable.dart';
import 'package:premium_force_main/models/user.dart';

/// Enum for the current authentication status.
enum AuthStatus {
  initial,
  loading,
  otpSent,
  otpVerified,
  authenticated,
  unauthenticated,
  failure,
}

/// State emitted by [AuthBloc].
class AuthState extends Equatable {
  final AuthStatus status;
  final UserModel? user;
  final String? phoneNumber;
  final String? errorMessage;

  /// Seconds remaining before the user can tap "Resend OTP".
  /// `0` means the button is enabled.
  final int resendCountdown;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.phoneNumber,
    this.errorMessage,
    this.resendCountdown = 0,
  });

  /// Convenience factory for the initial state.
  const AuthState.initial()
    : status = AuthStatus.initial,
      user = null,
      phoneNumber = null,
      errorMessage = null,
      resendCountdown = 0;

  /// Returns a copy of this state with the given fields replaced.
  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? phoneNumber,
    String? errorMessage,
    int? resendCountdown,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      errorMessage: errorMessage ?? this.errorMessage,
      resendCountdown: resendCountdown ?? this.resendCountdown,
    );
  }

  @override
  List<Object?> get props => [
    status,
    user,
    phoneNumber,
    errorMessage,
    resendCountdown,
  ];
}
