import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/marketplace.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_state_view.dart';

/// Service-catalog category picker composed for the v2 system (needs-design).
class HoCategoriesScreen extends ConsumerStatefulWidget {
  const HoCategoriesScreen({super.key});

  @override
  ConsumerState<HoCategoriesScreen> createState() => _HoCategoriesScreenState();
}

class _HoCategoriesScreenState extends ConsumerState<HoCategoriesScreen> {
  List<ServiceOption>? _catalog;
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await ref
          .read(jobsRepositoryProvider)
          .getServiceCatalog();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load services. Please try again.';
        _loading = false;
      });
    }
  }

  Map<String, List<ServiceOption>> get _categories {
    final grouped = <String, List<ServiceOption>>{};
    for (final service in _catalog ?? const <ServiceOption>[]) {
      final category = service.category.trim().isEmpty
          ? 'Other'
          : service.category.trim();
      grouped.putIfAbsent(category, () => []).add(service);
    }
    final query = _query.trim().toLowerCase();
    return {
      for (final entry in grouped.entries)
        if (query.isEmpty ||
            entry.key.toLowerCase().contains(query) ||
            entry.value.any(
              (service) => service.name.toLowerCase().contains(query),
            ))
          entry.key: entry.value,
    };
  }

  @override
  Widget build(BuildContext context) => ThScope(
    themeMode: ref.watch(themeModeProvider),
    child: THScaffold(
      appBar: const THAppBar(title: 'Categories'),
      scrollable: false,
      body: _loading && _catalog == null
          ? const ThStateView.loading(label: 'Loading services...')
          : _error != null && _catalog == null
          ? ThStateView.error(message: _error!, onRetry: _load)
          : _buildCatalog(context),
    ),
  );

  Widget _buildCatalog(BuildContext context) {
    final categories = _categories.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (_catalog?.isEmpty == true) {
      return const ThStateView.empty(
        icon: Icons.handyman_outlined,
        title: 'No services available',
        body: 'Please check back later.',
      );
    }
    if (_error != null && _catalog?.isNotEmpty == true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ThStateView.error(message: _error!, onRetry: _load),
          Expanded(child: _categoryList(categories)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        THTextField(
          label: 'Find a service',
          hint: 'Search plumbing, electrical, building…',
          icon: Icons.search,
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: Space.s3),
        Expanded(
          child: categories.isEmpty
              ? const ThStateView.empty(
                  icon: Icons.search_off_rounded,
                  title: 'No services match your search',
                )
              : _categoryList(categories),
        ),
      ],
    );
  }

  Widget _categoryList(
    List<MapEntry<String, List<ServiceOption>>> categories,
  ) => ListView.separated(
    itemCount: categories.length,
    separatorBuilder: (_, _) => const SizedBox(height: Space.s2),
    itemBuilder: (context, index) {
      final category = categories[index];
      return Semantics(
        button: true,
        label: 'Category ${category.key}, ${category.value.length} services',
        child: InkWell(
          onTap: () => context.push('/find-tradie', extra: category.key),
          borderRadius: BorderRadius.circular(Radii.card),
          child: THCard(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        THText(category.key, style: THTextStyle.title),
                        const SizedBox(height: Space.s1),
                        THText(
                          '${category.value.length} active services',
                          style: THTextStyle.meta,
                          tone: THTone.soft,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: context.th.textSoft),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
