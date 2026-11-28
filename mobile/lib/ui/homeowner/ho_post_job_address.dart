import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/jobs_viewmodel.dart';
import '../shared/th_address_lookup.dart';

class HoPostJobAddress extends ConsumerWidget {
  const HoPostJobAddress({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(postJobProvider);

    return ThAddressLookup(
      value: state.address,
      fieldKey: const Key('address_search_field'),
      selected: state.resolvedAddress != null,
      onChanged: ref.read(postJobProvider.notifier).setAddress,
      onSelected: (address, result) {
        ref
            .read(postJobProvider.notifier)
            .selectAddress(
              address,
              '${result.attribution}\n${result.attributionUrl}',
            );
      },
    );
  }
}
