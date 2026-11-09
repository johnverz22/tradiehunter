import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/marketplace.dart';
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

  ProfileState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? profile,
  }) {
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

  // P10-18: Toggle tradie availability
  Future<void> updateAvailability(bool isAvailable) async {
    try {
      await _repository.updateAvailability(isAvailable);
      // Optimistically update local state so UI responds immediately
      final updated = Map<String, dynamic>.from(state.profile ?? {});
      updated['isAvailable'] = isAvailable;
      state = state.copyWith(profile: updated);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final profileViewModelProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
      return ProfileNotifier(ref.watch(profileRepositoryProvider));
    });

// ── Tradie weekly earnings (v1.5 D4) ────────────────────────────────────────

/// Distinct states so the dashboard can tell "genuinely $0.00 this week"
/// (loaded) from "server has no figure for you" (null fields) and "the
/// endpoint failed" (error) — never collapsing them into a misleading zero.
class TradieEarningsState {
  final bool isLoading;
  final String? error;
  final TradieEarnings? summary;

  const TradieEarningsState({this.isLoading = false, this.error, this.summary});
}

class TradieEarningsNotifier extends StateNotifier<TradieEarningsState> {
  final ProfileRepository _repo;
  TradieEarningsNotifier(this._repo) : super(const TradieEarningsState());

  Future<void> load() async {
    state = TradieEarningsState(isLoading: true, summary: state.summary);
    try {
      final summary = await _repo.getEarnings();
      state = TradieEarningsState(summary: summary);
    } catch (e) {
      state = TradieEarningsState(
        summary: state.summary,
        error: e is ProfileApiException
            ? e.message
            : 'Could not load earnings. Please try again.',
      );
    }
  }
}

final tradieEarningsProvider =
    StateNotifierProvider<TradieEarningsNotifier, TradieEarningsState>(
      (ref) => TradieEarningsNotifier(ref.watch(profileRepositoryProvider)),
    );
