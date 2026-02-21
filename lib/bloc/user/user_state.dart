import 'package:equatable/equatable.dart';
import 'package:premium_force_main/models/user.dart';

/// Enum for user profile loading status.
enum UserStatus { initial, loading, loaded, failure }

/// State emitted by [UserBloc].
class UserState extends Equatable {
  final UserStatus status;
  final UserModel? user;
  final String? errorMessage;

  const UserState({
    this.status = UserStatus.initial,
    this.user,
    this.errorMessage,
  });

  /// Convenience factory for the initial state.
  const UserState.initial()
    : status = UserStatus.initial,
      user = null,
      errorMessage = null;

  /// Returns a copy of this state with the given fields replaced.
  UserState copyWith({
    UserStatus? status,
    UserModel? user,
    String? errorMessage,
  }) {
    return UserState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage];
}
