import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/design_tokens.dart';
import '../../models/marketplace.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../widgets/fixo_buttons.dart';
import '../../widgets/fixo_cards.dart';
import '../../widgets/fixo_states.dart';
import '../../widgets/th_components.dart';

/// H08 Categories (v1.6.2 frames-homeowner.html).
///
/// Wired to the REAL service catalog endpoint (`jobsRepository.getServiceCatalog`
/// → GET /api/services) and grouped by the catalog's own `category` field —
/// the mockup's static tiles become live tiles. Tapping a category opens the
/// H19 Find-a-Tradie screen seeded with that category.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  List<ServiceOption>? _catalog;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
    });
    try {
      final catalog = await ref
          .read(jobsRepositoryProvider)
          .getServiceCatalog();
      if (!mounted) return;
      setState(() => _catalog = catalog);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  /// Group catalog services by their category, sorted by service count desc.
  Map<String, List<ServiceOption>> _grouped() {
    final groups = <String, List<ServiceOption>>{};
    for (final s in _catalog ?? const <ServiceOption>[]) {
      final key = s.category.trim().isEmpty ? 'Other' : s.category.trim();
      groups.putIfAbsent(key, () => []).add(s);
    }
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return groups;
    return {
      for (final e in groups.entries)
        if (e.key.toLowerCase().contains(query) ||
            e.value.any((s) => s.name.toLowerCase().contains(query)))
          e.key: e.value,
    };
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;

    return Scaffold(
      backgroundColor: th.paper,
      appBar: const FixoAppBar(title: 'Categories'),
      body: SafeArea(
        bottom: false,
        child: _error != null && (_catalog == null || _catalog!.isEmpty)
            ? FixoErrorState(message: _error!, onRetry: _load)
            : _catalog == null
            ? const Center(child: FixoLoading())
            : _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final th = Theme.of(context).extension<THColors>()!;
    final grouped = _grouped();
    final categories = grouped.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.s4,
        Space.gutter,
        Space.navClearance,
      ),
      children: [
        // Live search — filters the real catalog as you type (H08 search field).
        Semantics(
          textField: true,
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search plumbing, electrical, building…',
              prefixIcon: Icon(
                Icons.search,
                size: Sizes.iconMd,
                color: th.textSoft,
              ),
              filled: true,
              fillColor: th.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Space.s4,
                vertical: Space.s4,
              ),
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
        ),
        const SizedBox(height: Space.s5),
        Text(
          _query.isEmpty ? 'Popular services' : 'Results',
          style: THType.caption.copyWith(color: th.textSoft),
        ),
        const SizedBox(height: Space.s2),
        if (categories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.s7),
            child: Text(
              'No services match your search.',
              style: THType.secondary.copyWith(color: th.textSoft),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: Space.s3,
              crossAxisSpacing: Space.s3,
              childAspectRatio: 1.6,
            ),
            itemCount: categories.length,
            itemBuilder: (_, i) {
              final c = categories[i];
              final services = grouped[c]!;
              return Semantics(
                button: true,
                label: 'Category $c, ${services.length} services',
                child: InkWell(
                  onTap: () => context.push('/find-tradie', extra: c),
                  borderRadius: BorderRadius.circular(Radii.tile),
                  child: Container(
                    padding: const EdgeInsets.all(Space.s4),
                    decoration: BoxDecoration(
                      color: th.surface,
                      borderRadius: BorderRadius.circular(Radii.tile),
                      border: Border.all(
                        color: th.line,
                        width: Sizes.borderWidthHair,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          c,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: THType.cardTitle.copyWith(color: th.text),
                        ),
                        const SizedBox(height: Space.s0_5),
                        Text(
                          '${services.length} active services',
                          style: THType.caption.copyWith(color: th.textSoft),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: Space.s5),
        // Trust card — the mockup's vetted-tradie reassurance block.
        FixoCard(
          child: Row(
            children: [
              THIconTile(icon: Icons.shield_outlined),
              const SizedBox(width: Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All tradies vetted',
                      style: THType.cardTitle.copyWith(color: th.text),
                    ),
                    Text(
                      'Licensed, insured & identity-checked',
                      style: THType.secondary.copyWith(color: th.textSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
