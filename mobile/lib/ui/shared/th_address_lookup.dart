import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/address.dart';
import '../../viewmodels/address_viewmodel.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

/// Default max length for an address query, matching the API's 160-char limit.
const int thAddressLookupMaxLength = 160;

/// Address autocomplete shared by the post-job and tradie-profile forms.
///
/// Owns the search field and the result list; callers keep the chosen value in
/// their own state and receive it through [onChanged] / [onSelected]. The
/// selected address's latitude and longitude are not exposed here — the server
/// derives them from the confirmed address.
class ThAddressLookup extends ConsumerStatefulWidget {
  const ThAddressLookup({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onSelected,
    this.eyebrow = 'WHERE IS THE JOB?',
    this.label = 'JOB ADDRESS',
    this.hint = 'Start with the street number and road name',
    this.helper = 'Select a result to confirm the job location.',
    this.selectedLabel = 'Address selected',
    this.selected = false,
    this.errorText,
    this.maxLength = thAddressLookupMaxLength,
    this.fieldKey,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final void Function(AddressCandidate candidate, AddressSearchResult result)
  onSelected;
  final String eyebrow;
  final String label;
  final String hint;
  final String helper;
  final String selectedLabel;

  /// True when [value] came from a confirmed search result.
  final bool selected;
  final String? errorText;
  final int maxLength;
  final Key? fieldKey;

  @override
  ConsumerState<ThAddressLookup> createState() => _ThAddressLookupState();
}

class _ThAddressLookupState extends ConsumerState<ThAddressLookup> {
  late final TextEditingController _controller;
  final _focus = FocusNode();
  bool _userHasEdited = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant ThAddressLookup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_userHasEdited &&
        widget.value.isNotEmpty &&
        _controller.text != widget.value) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.collapsed(
        offset: widget.value.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(addressSearchProvider);
    final showCounter =
        widget.maxLength > 0 &&
        widget.value.length >= (widget.maxLength * 0.8).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        THText(widget.eyebrow, style: THTextStyle.label, tone: THTone.soft),
        const SizedBox(height: Space.s2),
        THTextField(
          key: widget.fieldKey,
          label: widget.label,
          hint: widget.hint,
          icon: Icons.place_rounded,
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          inputFormatters: [LengthLimitingTextInputFormatter(widget.maxLength)],
          onChanged: (value) {
            _userHasEdited = true;
            widget.onChanged(value);
            ref.read(addressSearchProvider.notifier).edit(value);
          },
        ),
        if (showCounter)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: Space.s1),
              child: THText(
                '${widget.value.length} / ${widget.maxLength}',
                style: THTextStyle.meta,
                tone: THTone.soft,
              ),
            ),
          ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.s1),
            child: THText(
              widget.errorText!,
              style: THTextStyle.meta,
              tone: THTone.danger,
            ),
          ),
        const SizedBox(height: Space.s1),
        THText(widget.helper, style: THTextStyle.meta, tone: THTone.soft),
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
                  widget.onSelected(address, search.result!);
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
        if (widget.selected)
          Padding(
            padding: const EdgeInsets.only(top: Space.s2),
            child: Semantics(
              label: widget.selectedLabel,
              child: Align(
                alignment: Alignment.centerLeft,
                child: THBadge(
                  widget.selectedLabel,
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
