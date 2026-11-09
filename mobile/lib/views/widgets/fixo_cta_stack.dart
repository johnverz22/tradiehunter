// Shared primary+secondary action stack — extracted per
// mobile/HARDCODED_AUDIT.md Phase 4. View-only: no ViewModel or repository
// dependencies.

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../../widgets/fixo_buttons.dart';

/// The standard "primary CTA + secondary ghost" pairing used at the bottom of
/// flow screens (payment status, match result, job details).
class FixoCtaStack extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final Key? primaryKey;
  final bool primaryLoading;

  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Key? secondaryKey;

  const FixoCtaStack({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryKey,
    this.primaryLoading = false,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FixoPrimaryButton(
          key: primaryKey,
          label: primaryLabel,
          isLoading: primaryLoading,
          onPressed: onPrimary,
        ),
        if (secondaryLabel != null) ...[
          const SizedBox(height: Space.s2),
          FixoGhostButton(
            key: secondaryKey,
            label: secondaryLabel!,
            onPressed: onSecondary,
          ),
        ],
      ],
    );
  }
}
