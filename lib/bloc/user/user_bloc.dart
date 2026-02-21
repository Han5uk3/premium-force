import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:premium_force_main/bloc/user/user_event.dart';
import 'package:premium_force_main/bloc/user/user_state.dart';

/// BLoC that manages the current user's profile data.
///
/// Handles loading from a remote source and profile updates.
/// Replace the `// TODO` sections with real Firestore logic.
class UserBloc extends Bloc<UserEvent, UserState> {
  UserBloc() : super(const UserState.initial()) {
    on<UserLoadRequested>(_onLoadRequested);
    on<UserUpdateRequested>(_onUpdateRequested);
    on<UserCleared>(_onCleared);
  }

  // ---------------------------------------------------------------------------
  // Event handlers
  // ---------------------------------------------------------------------------

  /// Load a user profile by [uid].
  Future<void> _onLoadRequested(
    UserLoadRequested event,
    Emitter<UserState> emit,
  ) async {
    emit(state.copyWith(status: UserStatus.loading));
    try {
      // TODO: Fetch user data from Firestore.
      //   final doc = await FirebaseFirestore.instance
      //       .collection('users')
      //       .doc(event.uid)
      //       .get();
      //   if (doc.exists) {
      //     final user = UserModel.fromJson(doc.data()!);
      //     emit(state.copyWith(status: UserStatus.loaded, user: user));
      //   } else {
      //     emit(state.copyWith(
      //       status: UserStatus.failure,
      //       errorMessage: 'User not found',
      //     ));
      //   }

      // Placeholder – emits failure until Firestore is wired.
      emit(
        state.copyWith(
          status: UserStatus.failure,
          errorMessage: 'Firestore not yet connected',
        ),
      );
    } catch (e) {
      debugPrint('UserLoadRequested error: $e');
      emit(
        state.copyWith(status: UserStatus.failure, errorMessage: e.toString()),
      );
    }
  }

  /// Update the user profile (locally and remotely).
  Future<void> _onUpdateRequested(
    UserUpdateRequested event,
    Emitter<UserState> emit,
  ) async {
    emit(state.copyWith(status: UserStatus.loading));
    try {
      // TODO: Update data in Firestore.
      //   await FirebaseFirestore.instance
      //       .collection('users')
      //       .doc(event.user.uid)
      //       .update(event.user.toJson());

      emit(state.copyWith(status: UserStatus.loaded, user: event.user));
    } catch (e) {
      debugPrint('UserUpdateRequested error: $e');
      emit(
        state.copyWith(status: UserStatus.failure, errorMessage: e.toString()),
      );
    }
  }

  /// Clear user data (e.g. on logout).
  Future<void> _onCleared(UserCleared event, Emitter<UserState> emit) async {
    emit(const UserState.initial());
  }
}
