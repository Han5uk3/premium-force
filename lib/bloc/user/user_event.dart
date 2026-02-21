import 'package:equatable/equatable.dart';
import 'package:premium_force_main/models/user.dart';

/// Base class for all user-profile events.
abstract class UserEvent extends Equatable {
  const UserEvent();

  @override
  List<Object?> get props => [];
}

/// Fired to load the user profile (e.g. from Firestore).
class UserLoadRequested extends UserEvent {
  final String uid;

  const UserLoadRequested({required this.uid});

  @override
  List<Object?> get props => [uid];
}

/// Fired when the user updates their profile.
class UserUpdateRequested extends UserEvent {
  final UserModel user;

  const UserUpdateRequested({required this.user});

  @override
  List<Object?> get props => [user];
}

/// Fired to clear the cached user data (e.g. on logout).
class UserCleared extends UserEvent {
  const UserCleared();
}
