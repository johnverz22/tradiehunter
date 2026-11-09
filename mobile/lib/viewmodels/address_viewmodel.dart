import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/address.dart';
import '../repositories/address_repository.dart';
import '../theme/design_tokens.dart';
import '../repositories/profile_repository.dart';
import 'auth_viewmodel.dart';

final addressRepositoryProvider = Provider<AddressRepository>(
  (ref) => AddressRepository(
    ref.watch(dioProvider),
    ref.watch(secureStorageProvider),
  ),
);

class AddressSearchState {
  final bool loading;
  final bool searched;
  final AddressSearchResult? result;
  final String? error;

  const AddressSearchState({
    this.loading = false,
    this.searched = false,
    this.result,
    this.error,
  });
}

class AddressSearchNotifier extends StateNotifier<AddressSearchState> {
  final AddressRepository _repository;
  Timer? _timer;
  int _generation = 0;
  String _query = '';

  AddressSearchNotifier(this._repository) : super(const AddressSearchState());

  void edit(String query) {
    _query = query.trim();
    _timer?.cancel();
    final generation = ++_generation;
    state = const AddressSearchState();
    if (_query.length < 3) return;
    if (_query.length > 160 || _query.split(RegExp(r'\s+')).length > 12) {
      state = const AddressSearchState(
        error: 'Use up to 160 characters and 12 words.',
      );
      return;
    }
    state = const AddressSearchState(loading: true);
    _timer = Timer(
      FixoDurations.addressDebounce,
      () => _search(_query, generation),
    );
  }

  Future<void> retry() async {
    _timer?.cancel();
    if (_query.length < 3) return;
    await _search(_query, ++_generation);
  }

  void clear() {
    _timer?.cancel();
    ++_generation;
    state = const AddressSearchState();
  }

  Future<void> _search(String query, int generation) async {
    state = const AddressSearchState(loading: true);
    try {
      final result = await _repository.search(query);
      if (!mounted || generation != _generation) return;
      state = AddressSearchState(searched: true, result: result);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = AddressSearchState(
        error: error is ProfileApiException
            ? error.message
            : 'Could not search addresses. Please try again.',
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    ++_generation;
    super.dispose();
  }
}

final addressSearchProvider =
    StateNotifierProvider.autoDispose<
      AddressSearchNotifier,
      AddressSearchState
    >((ref) => AddressSearchNotifier(ref.watch(addressRepositoryProvider)));
