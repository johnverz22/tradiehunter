import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/design_tokens.dart';
import '../../models/address.dart';
import '../../models/marketplace.dart';
import '../../viewmodels/address_viewmodel.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../utils/money.dart' show formatMoney;
import '../../widgets/fixo_buttons.dart';
import '../../widgets/fixo_cards.dart';
import '../../widgets/fixo_states.dart';
import '../../widgets/th_components.dart';
import '../states/designed_empty_state.dart';

/// H19 Find a Tradie (v1.6.2 frames-homeowner.html).
///
/// Wired to REAL endpoints:
/// - service chips from `jobsRepository.getServiceCatalog()` (GET /api/services)
/// - tradie search via `jobsRepository.searchServiceRates(serviceId, lat, lng)`
///   (GET /api/services/search) — the same source the matching flow uses.
/// Location comes from the address autocomplete (shared [addressSearchProvider]);
/// until an address is chosen the screen shows the designed guidance state.
///
/// [initialCategory] (route extra from H08) pre-selects the matching chips.
class BrowseTradiesScreen extends ConsumerStatefulWidget {
  final String? initialCategory;

  const BrowseTradiesScreen({super.key, this.initialCategory});

  @override
  ConsumerState<BrowseTradiesScreen> createState() =>
      _BrowseTradiesScreenState();
}

class _BrowseTradiesScreenState extends ConsumerState<BrowseTradiesScreen> {
  List<ServiceOption>? _catalog;
  String? _catalogError;

  ServiceOption? _selectedService;
  AddressCandidate? _location;
  List<ServiceRateOption>? _results;
  bool _searching = false;
  String? _searchError;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final catalog = await ref
          .read(jobsRepositoryProvider)
          .getServiceCatalog();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        // Pre-select from H08 when the catalog carries the category.
        if (widget.initialCategory != null) {
          final matches = catalog
              .where(
                (s) =>
                    s.category.toLowerCase() ==
                    widget.initialCategory!.toLowerCase(),
              )
              .toList();
          if (matches.isNotEmpty) {
            _selectedService = matches.first;
          }
        }
      });
      if (_selectedService != null && _location != null) _search();
    } catch (e) {
      if (!mounted) return;
      setState(() => _catalogError = e.toString());
    }
  }

  Future<void> _search() async {
    final service = _selectedService;
    final loc = _location;
    if (service == null || loc == null) return;

    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await ref
          .read(jobsRepositoryProvider)
          .searchServiceRates(
            serviceId: service.id,
            latitude: loc.latitude,
            longitude: loc.longitude,
          );
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = e.toString();
        _searching = false;
      });
    }
  }

  void _onServiceTap(ServiceOption service) {
    setState(() => _selectedService = service);
    _search();
  }

  void _onAddressChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(addressSearchProvider.notifier).edit(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    final addressState = ref.watch(addressSearchProvider);

    return Scaffold(
      backgroundColor: th.paper,
      appBar: const FixoAppBar(title: 'Find a Tradie'),
      body: SafeArea(
        bottom: false,
        child: _catalogError != null && (_catalog == null || _catalog!.isEmpty)
            ? FixoErrorState(message: _catalogError!, onRetry: _loadCatalog)
            : _buildBody(context, addressState),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AddressSearchState addressState) {
    final th = Theme.of(context).extension<THColors>()!;
    final catalog = _catalog ?? const <ServiceOption>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.s4,
        Space.gutter,
        Space.navClearance,
      ),
      children: [
        // Service filter chips — horizontal scroll + fade (mockup rule).
        SizedBox(
          height: Sizes.tapMin,
          child: THFadeRow(
            fadeWidth: Space.s7,
            children: [
              for (final s in catalog)
                GestureDetector(
                  onTap: () => _onServiceTap(s),
                  child: THFilterChip(
                    label: s.name,
                    selected: _selectedService?.id == s.id,
                    outlined: _selectedService?.id != s.id,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.s3),

        // Where — address autocomplete feeding the real search endpoint.
        Text('Where', style: THType.caption.copyWith(color: th.textSoft)),
        const SizedBox(height: Space.s2),
        TextField(
          onChanged: _onAddressChanged,
          decoration: InputDecoration(
            hintText: 'Enter a suburb or address',
            prefixIcon: Icon(
              Icons.place_outlined,
              size: Sizes.iconMd,
              color: th.textSoft,
            ),
            filled: true,
            fillColor: th.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.control),
              borderSide: BorderSide(color: th.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.control),
              borderSide: BorderSide(
                color: DesignTokens.borderControl(
                  Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
          ),
        ),

        // Autocomplete candidates (real AddressRepository results).
        if (addressState.loading)
          const Padding(padding: EdgeInsets.all(Space.s3), child: FixoLoading())
        else if (addressState.result != null &&
            addressState.result!.items.isNotEmpty)
          FixoCard(
            child: Column(
              children: [
                for (final candidate in addressState.result!.items.take(4))
                  THListRow(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        Icons.place_outlined,
                        size: Sizes.iconSm,
                        color: th.textSoft,
                      ),
                      title: Text(
                        candidate.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: THType.secondary.copyWith(color: th.text),
                      ),
                      onTap: () {
                        setState(() {
                          _location = candidate;
                          _results = null;
                        });
                        // Collapse the suggestion list by clearing the query.
                        ref.read(addressSearchProvider.notifier).edit('');
                        _search();
                      },
                    ),
                  ),
              ],
            ),
          ),

        const SizedBox(height: Space.s4),

        // Results / guidance.
        if (_selectedService == null || _location == null)
          Padding(
            padding: const EdgeInsets.only(top: Space.s6),
            child: Column(
              children: [
                Text(
                  'Pick a service and a location',
                  style: THType.section.copyWith(color: th.text),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.s2),
                Text(
                  'We\'ll show verified tradies near you with their live rates.',
                  style: THType.secondary.copyWith(color: th.textSoft),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else if (_searching)
          const Padding(
            padding: EdgeInsets.all(Space.s6),
            child: Center(child: FixoLoading()),
          )
        else if (_searchError != null)
          FixoErrorState(message: _searchError!, onRetry: _search)
        else if (_results != null && _results!.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Space.s6),
            child: DesignedEmptyState(variant: DesignedStateVariant.emptyLeads),
          )
        else if (_results != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_results!.length} tradie${_results!.length == 1 ? '' : 's'} near ${_location!.suburb ?? _location!.city ?? 'you'}',
                style: THType.caption.copyWith(color: th.textSoft),
              ),
              const SizedBox(height: Space.s2),
              for (final r in _results!)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.s3),
                  child: _TradieRateCard(option: r),
                ),
            ],
          ),
      ],
    );
  }
}

/// One search result — tradie name, business, hourly rate, distance.
class _TradieRateCard extends StatelessWidget {
  final ServiceRateOption option;

  const _TradieRateCard({required this.option});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    final initials = option.name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();

    return Container(
      padding: const EdgeInsets.all(Space.s4),
      decoration: BoxDecoration(
        color: th.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: th.line, width: Sizes.borderWidthHair),
      ),
      child: Row(
        children: [
          Container(
            width: Sizes.avatarMd,
            height: Sizes.avatarMd,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: th.avTradie,
            ),
            child: Text(
              initials,
              style: THType.secondaryW600.copyWith(color: th.onAvTradie),
            ),
          ),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: THType.cardTitle.copyWith(color: th.text),
                ),
                if (option.businessName != null &&
                    option.businessName!.isNotEmpty)
                  Text(
                    option.businessName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: THType.secondary.copyWith(color: th.textSoft),
                  ),
                Text(
                  '${option.distanceKm.toStringAsFixed(1)} km away',
                  style: THType.caption.copyWith(color: th.textSoft),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(option.hourlyRate),
                style: THType.price.copyWith(color: th.textBrand),
              ),
              Text(
                'per hour',
                style: THType.caption.copyWith(color: th.textSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
