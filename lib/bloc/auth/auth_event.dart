import 'dart:io';

import 'package:equatable/equatable.dart';

/// Base class for all authentication events.
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Fired when the user requests an OTP for the given [phoneNumber].
class AuthOtpRequested extends AuthEvent {
  final String countryCode;
  final String phoneNumber;

  const AuthOtpRequested({
    required this.countryCode,
    required this.phoneNumber,
  });

  @override
  List<Object?> get props => [countryCode, phoneNumber];
}

/// Fired when the user submits the [otp] for verification.
class AuthOtpVerified extends AuthEvent {
  final String otp;
  final String countryCode;
  final String phoneNumber;

  const AuthOtpVerified({
    required this.otp,
    required this.countryCode,
    required this.phoneNumber,
  });

  @override
  List<Object?> get props => [otp, countryCode, phoneNumber];
}

/// Fired when the user completes the signup form.
class AuthSignUpSubmitted extends AuthEvent {
  final String username;
  final String email;
  final String countryCode;
  final String phoneNumber;
  final String? location;
  final double? lat;
  final double? long;
  final File? profileImage;
  final String? specialId;

  const AuthSignUpSubmitted({
    required this.username,
    required this.email,
    required this.countryCode,
    required this.phoneNumber,
    this.location,
    this.lat,
    this.long,
    this.profileImage,
    this.specialId,
  });

  @override
  List<Object?> get props => [
    username,
    email,
    countryCode,
    phoneNumber,
    location,
    lat,
    long,
    profileImage,
    specialId,
  ];
}

/// Fired when the user requests a resend of the OTP.
class AuthOtpResendRequested extends AuthEvent {
  final String countryCode;
  final String phoneNumber;

  const AuthOtpResendRequested({
    required this.countryCode,
    required this.phoneNumber,
  });

  @override
  List<Object?> get props => [countryCode, phoneNumber];
}

/// Internal event – fired every second while the resend cooldown timer ticks.
class AuthResendTimerTicked extends AuthEvent {
  final int remainingSeconds;

  const AuthResendTimerTicked({required this.remainingSeconds});

  @override
  List<Object?> get props => [remainingSeconds];
}

/// Fired when the user logs out.
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Fired to check the current auth session on app start.
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}
