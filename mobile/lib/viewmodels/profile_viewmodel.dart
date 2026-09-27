import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/profile_repository.dart';
import 'auth_viewmodel.dart';

// Re-use the shared ProfileRepository provider declared in auth_viewmodel.dart
// so there is a single Dio + storage instance for profile calls.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ref.watch(sharedProfileRepositoryProvider);
});

class ProfileState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? profile;

  ProfileState({this.isLoading = false, this.error, this.profile});

  ProfileState copyWith(
      {bool? isLoading, String? error, Map<String, dynamic>? profile}) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      profile: profile ?? this.profile,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository _repository;

  ProfileNotifier(this._repository) : super(ProfileState()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await _repository.getCurrentProfile();
      state = state.copyWith(isLoading: false, profile: profile);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.updateProfile(data);
      await loadProfile();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final profileViewModelProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier(ref.watch(profileRepositoryProvider));
});
