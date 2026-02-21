import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/bloc/auth/auth_event.dart';
import 'package:premium_force_main/bloc/auth/auth_state.dart';
import 'package:premium_force_main/models/user.dart';

/// BLoC that manages the full authentication lifecycle.
///
/// Uses [ApiService] to communicate with the AWS backend.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  static const int resendDuration = 60; // seconds

  final ApiService _api = ApiService();
  Timer? _resendTimer;

  AuthBloc() : super(const AuthState.initial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthOtpRequested>(_onOtpRequested);
    on<AuthOtpVerified>(_onOtpVerified);
    on<AuthOtpResendRequested>(_onOtpResendRequested);
    on<AuthResendTimerTicked>(_onResendTimerTicked);
    on<AuthSignUpSubmitted>(_onSignUpSubmitted);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  // ---------------------------------------------------------------------------
  // Timer helpers
  // ---------------------------------------------------------------------------

  void _startResendTimer() {
    _cancelResendTimer();
    int remaining = resendDuration;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      if (remaining <= 0) {
        timer.cancel();
        add(const AuthResendTimerTicked(remainingSeconds: 0));
      } else {
        add(AuthResendTimerTicked(remainingSeconds: remaining));
      }
    });
  }

  void _cancelResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = null;
  }

  @override
  Future<void> close() {
    _cancelResendTimer();
    return super.close();
  }

  // ---------------------------------------------------------------------------
  // Event handlers
  // ---------------------------------------------------------------------------

  /// Check whether the user is already logged in (e.g. on app start).
  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      // TODO: Check stored token / session.
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    } catch (e) {
      debugPrint('AuthCheckRequested error: $e');
      emit(
        state.copyWith(status: AuthStatus.failure, errorMessage: e.toString()),
      );
    }
  }

  /// Send an OTP to the provided phone number.
  Future<void> _onOtpRequested(
    AuthOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    // TODO: BYPASS — SMS service not implemented yet.
    // Uncomment the API call below when ready.
    // final result = await _api.sendOtp(
    //   countryCode: event.countryCode,
    //   phoneNumber: event.phoneNumber,
    // );

    _startResendTimer();
    emit(
      state.copyWith(
        status: AuthStatus.otpSent,
        phoneNumber: event.phoneNumber,
        resendCountdown: resendDuration,
      ),
    );
  }

  /// Verify the OTP entered by the user.
  Future<void> _onOtpVerified(
    AuthOtpVerified event,
    Emitter<AuthState> emit,
  ) async {
    // TODO: BYPASS — SMS service not implemented yet.
    // Uncomment the API call below when ready.
    // final result = await _api.verifyOtp(
    //   countryCode: event.countryCode,
    //   phoneNumber: event.phoneNumber,
    //   otp: event.otp,
    // );

    _cancelResendTimer();
    emit(
      state.copyWith(
        status: AuthStatus.otpVerified,
        phoneNumber: event.phoneNumber,
        resendCountdown: 0,
      ),
    );
  }

  /// Resend the OTP and restart the cooldown timer.
  Future<void> _onOtpResendRequested(
    AuthOtpResendRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state.resendCountdown > 0) return;

    // TODO: BYPASS — SMS service not implemented yet.
    // Uncomment the API call below when ready.
    // final result = await _api.sendOtp(
    //   countryCode: event.countryCode,
    //   phoneNumber: event.phoneNumber,
    // );

    _startResendTimer();
    emit(
      state.copyWith(
        status: AuthStatus.otpSent,
        phoneNumber: event.phoneNumber,
        resendCountdown: resendDuration,
      ),
    );
  }

  /// Update the countdown every tick.
  void _onResendTimerTicked(
    AuthResendTimerTicked event,
    Emitter<AuthState> emit,
  ) {
    emit(state.copyWith(resendCountdown: event.remainingSeconds));
  }

  /// Create the user profile after signup form submission.
  Future<void> _onSignUpSubmitted(
    AuthSignUpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final result = await _api.createUser(
        username: event.username,
        email: event.email,
        countryCode: event.countryCode,
        phoneNumber: event.phoneNumber,
        location: event.location,
        lat: event.lat,
        long: event.long,
        profileImage: event.profileImage,
        specialId: event.specialId,
      );

      if (result['success'] == true) {
        final userData = result['user'] ?? result['data'] ?? result;
        final user = UserModel.fromJson(userData as Map<String, dynamic>);
        emit(state.copyWith(status: AuthStatus.authenticated, user: user));
      } else {
        emit(
          state.copyWith(
            status: AuthStatus.failure,
            errorMessage: result['message'] as String? ?? 'Signup failed',
          ),
        );
      }
    } catch (e) {
      debugPrint('AuthSignUpSubmitted error: $e');
      emit(
        state.copyWith(status: AuthStatus.failure, errorMessage: e.toString()),
      );
    }
  }

  /// Sign the user out.
  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      _cancelResendTimer();
      emit(
        const AuthState.initial().copyWith(status: AuthStatus.unauthenticated),
      );
    } catch (e) {
      debugPrint('AuthLogoutRequested error: $e');
      emit(
        state.copyWith(status: AuthStatus.failure, errorMessage: e.toString()),
      );
    }
  }
}
