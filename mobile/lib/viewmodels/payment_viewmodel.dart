import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/marketplace.dart';
import '../models/payment.dart';
import '../repositories/payments_repository.dart';
import 'auth_viewmodel.dart' show dioProvider, secureStorageProvider;
import 'jobs_viewmodel.dart' show jobsRepositoryProvider;

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  return PaymentsRepository(
    ref.watch(dioProvider),
    ref.watch(secureStorageProvider),
  );
});

/// Payment state for one job (P4-07).
class PaymentState {
  final bool isLoading;

  /// True only while a receipt is uploading, so the screen can show progress
  /// without replacing the instructions the homeowner is reading.
  final bool isUploading;

  final PaymentStatus? payment;
  final String? error;

  const PaymentState({
    this.isLoading = false,
    this.isUploading = false,
    this.payment,
    this.error,
  });

  PaymentState copyWith({
    bool? isLoading,
    bool? isUploading,
    PaymentStatus? payment,
    String? error,
    bool clearError = false,
  }) => PaymentState(
    isLoading: isLoading ?? this.isLoading,
    isUploading: isUploading ?? this.isUploading,
    payment: payment ?? this.payment,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Drives the homeowner's payment flow for a single job.
///
/// Uploading a receipt is optimistic only in the sense that the server responds
/// with the authoritative new state — there is no local guess at what the
/// payment status becomes, because staff verification happens later.
class PaymentNotifier extends StateNotifier<PaymentState> {
  final PaymentsRepository _repo;
  final String jobId;

  PaymentNotifier(this._repo, this.jobId) : super(const PaymentState());

  /// Loads instructions and current state. Safe to call on every rebuild of the
  /// screen so returning to it reflects a rejection that landed while away.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final payment = await _repo.getPayment(jobId);
      state = state.copyWith(isLoading: false, payment: payment);
    } on PaymentAccessException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  /// Uploads [filePath] as the bank receipt. On success the returned state is
  /// the server's — the job is now in staff review, not paid.
  Future<bool> uploadReceipt(String filePath) async {
    state = state.copyWith(isUploading: true, clearError: true);
    try {
      final payment = await _repo.uploadReceipt(jobId, filePath);
      state = state.copyWith(isUploading: false, payment: payment);
      return true;
    } on PaymentAccessException catch (e) {
      state = state.copyWith(isUploading: false, error: e.message);
      return false;
    }
  }
}

/// One notifier per job, so two payment screens in the stack don't share state.
final paymentViewModelProvider = StateNotifierProvider.autoDispose
    .family<PaymentNotifier, PaymentState, String>(
      (ref, jobId) =>
          PaymentNotifier(ref.watch(paymentsRepositoryProvider), jobId),
    );

/// The job behind a payment, fetched separately so a slow or failed job read
/// can never block the payment instructions. The payment screen uses this for
/// the hours × rate breakdown only — `null` means "show the total alone",
/// never an invented rate.
final paymentJobProvider = FutureProvider.autoDispose.family<Job?, String>(
  (ref, jobId) => ref.watch(jobsRepositoryProvider).getJobById(jobId),
);
