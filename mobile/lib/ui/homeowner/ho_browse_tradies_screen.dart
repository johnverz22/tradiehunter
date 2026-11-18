import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/address.dart';
import '../../models/marketplace.dart';
import '../../viewmodels/address_viewmodel.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../../utils/money.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_state_view.dart';
import '../shared/th_choice_pills.dart';

/// Real service and address search composed for the v2 system (needs-design).
class HoBrowseTradiesScreen extends ConsumerStatefulWidget {
  const HoBrowseTradiesScreen({super.key, this.initialCategory});
  final String? initialCategory;

  @override
  ConsumerState<HoBrowseTradiesScreen> createState() =>
      _HoBrowseTradiesScreenState();
}

class _HoBrowseTradiesScreenState extends ConsumerState<HoBrowseTradiesScreen> {
  List<ServiceOption>? _catalog;
  ServiceOption? _service;
  AddressCandidate? _location;
  List<ServiceRateOption>? _results;
  bool _loadingCatalog = true;
  bool _searching = false;
  String? _catalogError;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loadingCatalog = true;
      _catalogError = null;
    });
    try {
      final catalog = await ref
          .read(jobsRepositoryProvider)
          .getServiceCatalog();
      if (!mounted) return;
      final seeded = catalog
          .where(
            (service) =>
                service.category.toLowerCase() ==
                widget.initialCategory?.toLowerCase(),
          )
          .firstOrNull;
      setState(() {
        _catalog = catalog;
        _service = seeded;
        _loadingCatalog = false;
      });
      if (seeded != null && _location != null) _search();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _catalogError = 'Could not load services. Please try again.';
        _loadingCatalog = false;
      });
    }
  }

  Future<void> _search() async {
    final service = _service;
    final location = _location;
    if (service == null || location == null) return;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await ref
          .read(jobsRepositoryProvider)
          .searchServiceRates(
            serviceId: service.id,
            latitude: location.latitude,
            longitude: location.longitude,
          );
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchError = 'Could not search nearby tradies. Please try again.';
        _searching = false;
      });
    }
  }

  void _selectAddress(AddressCandidate candidate) {
    setState(() {
      _location = candidate;
      _results = null;
    });
    ref.read(addressSearchProvider.notifier).clear();
    _search();
  }

  @override
  Widget build(BuildContext context) => ThScope(
    themeMode: ref.watch(themeModeProvider),
    child: Builder(
      builder: (context) => THScaffold(
        appBar: const THAppBar(title: 'Find a tradie'),
        scrollable: false,
        body: _loadingCatalog && _catalog == null
            ? const ThStateView.loading(label: 'Loading services...')
            : _catalogError != null && _catalog == null
            ? ThStateView.error(message: _catalogError!, onRetry: _loadCatalog)
            : _buildSearch(context),
      ),
    ),
  );

  Widget _buildSearch(BuildContext context) {
    final catalog = _catalog ?? const <ServiceOption>[];
    final addressState = ref.watch(addressSearchProvider);
    return ListView(
      padding: EdgeInsets.only(bottom: thDockClearance(context)),
      children: [
        if (_catalogError != null)
          ThStateView.error(message: _catalogError!, onRetry: _loadCatalog),
        const THText('Choose a service', style: THTextStyle.title),
        const SizedBox(height: Space.s2),
        ThChoicePills(
          items: [
            for (final service in catalog)
              ThChoicePillItem(
                label: service.name,
                selected: service.id == _service?.id,
                onSelected: () {
                  setState(() {
                    _service = service;
                    _results = null;
                  });
                  _search();
                },
              ),
          ],
        ),
        const SizedBox(height: Space.s4),
        THTextField(
          label: 'Where',
          hint: 'Enter a suburb or address',
          icon: Icons.place_outlined,
          onChanged: (query) =>
              ref.read(addressSearchProvider.notifier).edit(query),
        ),
        if (addressState.loading)
          const Padding(
            padding: EdgeInsets.all(Space.s3),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (addressState.error != null)
          THCard(
            children: [
              THText(
                addressState.error!,
                style: THTextStyle.body,
                tone: THTone.danger,
              ),
            ],
          ),
        if (addressState.result?.items.isNotEmpty == true)
          THCard(
            children: [
              for (final candidate in addressState.result!.items.take(4))
                Material(
                  color: context.th.surface,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on_outlined),
                    title: THText(candidate.address, style: THTextStyle.body),
                    onTap: () => _selectAddress(candidate),
                  ),
                ),
            ],
          ),
        if (_location != null)
          THCard(
            children: [
              THKeyValue('Selected location', _location!.address),
              const THText(
                'Tradies near this address',
                style: THTextStyle.title,
              ),
            ],
          ),
        const SizedBox(height: Space.s3),
        if (_service == null || _location == null)
          const ThStateView.empty(
            icon: Icons.travel_explore_rounded,
            title: 'Pick a service and location',
            body: 'We’ll show available tradies and their current rates.',
          )
        else if (_searching)
          const ThStateView.loading(label: 'Searching nearby tradies...')
        else if (_searchError != null)
          ThStateView.error(message: _searchError!, onRetry: _search)
        else if (_results?.isEmpty == true)
          const ThStateView.empty(
            icon: Icons.person_search_outlined,
            title: 'No tradies found nearby',
            body: 'Try another service or location.',
          )
        else if (_results != null) ...[
          THText(
            '${_results!.length} tradies near ${_location!.suburb ?? _location!.city ?? 'your location'}',
            style: THTextStyle.meta,
            tone: THTone.soft,
          ),
          const SizedBox(height: Space.s2),
          for (final result in _results!) _TradieRateCard(result: result),
        ],
      ],
    );
  }
}

class _TradieRateCard extends StatelessWidget {
  const _TradieRateCard({required this.result});
  final ServiceRateOption result;

  @override
  Widget build(BuildContext context) {
    final name = result.businessName?.trim().isNotEmpty == true
        ? result.businessName!.trim()
        : result.name;
    final initials = result.name
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase())
        .take(2)
        .join();
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s2),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: () => context.push('/tradie/${result.tradieId}'),
        child: THCard(
          children: [
            Row(
              spacing: Space.s3,
              children: [
                THAvatar(initials.isEmpty ? '?' : initials),
                Expanded(child: THText(name, style: THTextStyle.title)),
                THText(
                  formatMoney(result.hourlyRate),
                  style: THTextStyle.money,
                ),
              ],
            ),
            const SizedBox(height: Space.s2),
            THKeyValue(
              'Distance',
              '${result.distanceKm.toStringAsFixed(1)} km',
            ),
            const THText(
              'Hourly rate',
              style: THTextStyle.meta,
              tone: THTone.soft,
            ),
          ],
        ),
      ),
    );
  }
}
