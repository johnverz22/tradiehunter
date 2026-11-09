import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/jobs_repository.dart';
import '../repositories/profile_repository.dart';
import 'jobs_viewmodel.dart'; // To get jobsRepositoryProvider

class DisputeState {
  final bool isSubmitting;
  final String? error;
  final String? disputeId;
  final String reason;
  final String details;
  final List<String> photoPaths;

  const DisputeState({
    this.isSubmitting = false,
    this.error,
    this.disputeId,
    this.reason = 'Poor Quality',
    this.details = '',
    this.photoPaths = const [],
  });

  DisputeState copyWith({
    bool? isSubmitting,
    String? error,
    String? disputeId,
    String? reason,
    String? details,
    List<String>? photoPaths,
  }) {
    return DisputeState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      disputeId: disputeId ?? this.disputeId,
      reason: reason ?? this.reason,
      details: details ?? this.details,
      photoPaths: photoPaths ?? this.photoPaths,
    );
  }
}

class DisputeNotifier extends StateNotifier<DisputeState> {
  final JobsRepository _repo;

  DisputeNotifier(this._repo) : super(const DisputeState());

  void setReason(String reason) => state = state.copyWith(reason: reason);
  void setDetails(String details) => state = state.copyWith(details: details);

  void addPhoto(String path) {
    if (state.photoPaths.length >= 5) return;
    state = state.copyWith(photoPaths: [...state.photoPaths, path]);
  }

  void removePhoto(String path) {
    state = state.copyWith(
      photoPaths: state.photoPaths.where((p) => p != path).toList(),
    );
  }

  Future<bool> submitDispute(String jobId) async {
    if (state.details.trim().isEmpty) {
      state = state.copyWith(error: 'Please provide details for the dispute.');
      return false;
    }

    state = state.copyWith(isSubmitting: true, error: null);

    final String disputeId;
    try {
      disputeId = await _repo.openDispute(jobId, state.reason, state.details);
    } on ProfileApiException catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.message);
      return false;
    }

    if (state.photoPaths.isNotEmpty || state.details.isNotEmpty) {
      try {
        await _repo.uploadDisputeEvidence(
          disputeId,
          state.photoPaths,
          state.details,
        );
      } on ProfileApiException catch (e) {
        state = state.copyWith(
          isSubmitting: false,
          error: 'Dispute opened, but evidence was not uploaded. ${e.message}',
        );
        return false;
      }
    }

    state = state.copyWith(isSubmitting: false, disputeId: disputeId);
    return true;
  }
}

final disputeProvider =
    StateNotifierProvider.autoDispose<DisputeNotifier, DisputeState>((ref) {
      return DisputeNotifier(ref.watch(jobsRepositoryProvider));
    });
