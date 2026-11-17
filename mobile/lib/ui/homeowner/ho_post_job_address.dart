import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/address_viewmodel.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import 'ho_post_job_mapper.dart';

class HoPostJobAddress extends ConsumerStatefulWidget {
  const HoPostJobAddress({super.key});

  @override
  ConsumerState<HoPostJobAddress> createState() => _HoPostJobAddressState();
}

class _HoPostJobAddressState extends ConsumerState<HoPostJobAddress> {
  late final TextEditingController _controller;
  final _focus = FocusNode();
  bool _userHasEdited = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(postJobProvider).address,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PostJobState>(postJobProvider, (previous, next) {
      if (!_userHasEdited &&
          next.address.isNotEmpty &&
          _controller.text != next.address) {
        _controller.text = next.address;
        _controller.selection = TextSelection.collapsed(
          offset: next.address.length,
        );
      }
    });

    final search = ref.watch(addressSearchProvider);
    final state = ref.watch(postJobProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        THText(
          'WHERE IS THE JOB?',
          style: THTextStyle.label,
          tone: THTone.soft,
        ),
        const SizedBox(height: Space.s2),
        THTextField(
          key: const Key('address_search_field'),
          label: 'JOB ADDRESS',
          hint: 'Start with the street number and road name',
          icon: Icons.place_rounded,
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          inputFormatters: [
            LengthLimitingTextInputFormatter(thAddressMaxLength),
          ],
          onChanged: (value) {
            _userHasEdited = true;
            ref.read(postJobProvider.notifier).setAddress(value);
            ref.read(addressSearchProvider.notifier).edit(value);
          },
        ),
        if (thShowCounter(state.address.length, thAddressMaxLength))
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: Space.s1),
              child: THText(
                '${state.address.length} / $thAddressMaxLength',
                style: THTextStyle.meta,
                tone: THTone.soft,
              ),
            ),
          ),
        const SizedBox(height: Space.s1),
        THText(
          'Select a result to confirm the job location.',
          style: THTextStyle.meta,
          tone: THTone.soft,
        ),
        if (search.loading)
          const Padding(
            padding: EdgeInsets.only(top: Space.s2),
            child: LinearProgressIndicator(
              semanticsLabel: 'Searching addresses',
            ),
          ),
        if (search.error != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: Space.s2),
            child: THText(
              search.error!,
              style: THTextStyle.meta,
              tone: THTone.danger,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: THButton(
              label: 'Retry address search',
              kind: THButtonKind.ghost,
              size: THButtonSize.sm,
              fullWidth: false,
              onPressed: ref.read(addressSearchProvider.notifier).retry,
            ),
          ),
        ],
        if (search.searched && search.result!.items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Space.s2),
            child: THText(
              'No matching addresses. Check the street number and spelling, '
              'or add the town or city.',
              style: THTextStyle.meta,
              tone: THTone.soft,
            ),
          ),
        for (final address in search.result?.items ?? const [])
          Padding(
            padding: const EdgeInsets.only(top: Space.s2),
            child: Semantics(
              button: true,
              label: 'Select ${address.address}',
              child: InkWell(
                onTap: () {
                  _userHasEdited = false;
                  _controller.text = address.address;
                  ref
                      .read(postJobProvider.notifier)
                      .selectAddress(
                        address,
                        '${search.result!.attribution}\n'
                        '${search.result!.attributionUrl}',
                      );
                  ref.read(addressSearchProvider.notifier).clear();
                  FocusScope.of(context).unfocus();
                },
                borderRadius: BorderRadius.circular(Radii.card),
                child: THListRow(
                  icon: Icons.place_outlined,
                  title: address.address,
                  subtitle: address.city,
                ),
              ),
            ),
          ),
        if (state.resolvedAddress != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.s2),
            child: Semantics(
              label: 'Job address selected',
              child: Align(
                alignment: Alignment.centerLeft,
                child: THBadge(
                  'Address selected',
                  kind: THBadgeKind.ok,
                  icon: Icons.check_rounded,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
