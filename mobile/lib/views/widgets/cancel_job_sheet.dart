import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../widgets/fixo_feedback.dart';


/// Shared "Cancel Job" bottom sheet (P6-03), used by both the homeowner
/// and tradie job detail screens.
///
/// Lets the user pick a reason code and enter optional notes before
/// confirming cancellation. Returns a record with the selected
/// [reasonCode] and [notes], or null if dismissed.
class CancelJobSheet extends StatefulWidget {
  final bool isTradie;
  final List<(String, String)> reasons; // (reasonCode, label)

  /// Optional status-specific warning shown above the reason picker. Falls
  /// back to the generic cancellation copy when not provided.
  final String? warning;

  const CancelJobSheet({
    super.key,
    required this.isTradie,
    required this.reasons,
    this.warning,
  });

  @override
  State<CancelJobSheet> createState() => CancelJobSheetState();
}

class CancelJobSheetState extends State<CancelJobSheet> {
  String? _selectedReason;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final errorColor = theme.colorScheme.error;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: Space.s3),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? DesignTokens.paperLineDark
                      : DesignTokens.paperLineLight,
                  borderRadius: BorderRadius.circular(Radii.micro),
                ),
              ),
            ),

            // Title + warning
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.s6, 0, Space.s6, Space.s1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cancel this job',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FW.bold,
                    ),
                  ),
                  const SizedBox(height: Space.s2),
                  FixoInfoBanner(
                      icon: Icons.warning_amber_outlined,
                      color: errorColor,
                      message: widget.warning ??
                          (widget.isTradie
                              ? 'Repeated cancellations will flag your account and may affect your ranking.'
                              : 'Cancellation fees may apply depending on how far along the job is.'),
                    ),
                  const SizedBox(height: Space.s4),

                  // Reason selector
                  Text(
                    'Reason',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FW.semibold,
                    ),
                  ),
                  const SizedBox(height: Space.s2),
                ],
              ),
            ),

            // Reason list
            RadioGroup<String>(
              groupValue: _selectedReason,
              onChanged: (v) => setState(() => _selectedReason = v),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...widget.reasons.map(((String, String) r) {
                    final code = r.$1;
                    final label = r.$2;
                    return RadioListTile<String>(
                      value: code,
                      title: Text(label, style: const TextStyle(fontSize: DesignTokens.fontSizeSm)),
                      dense: true,
                      activeColor: DesignTokens.brand500,
                      contentPadding: const EdgeInsets.symmetric(horizontal: Space.s6),
                    );
                  }),
                ],
              ),
            ),

            // Optional notes
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.s6, Space.s3, Space.s6, Space.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Additional notes (optional)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FW.semibold,
                    ),
                  ),
                  const SizedBox(height: Space.s1_5),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Any additional context…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radiusInput,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.s4),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('cancel_confirm_button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: errorColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            DesignTokens.radiusControl,
                          ),
                        ),
                      ),
                      onPressed: _selectedReason == null
                          ? null
                          : () => Navigator.of(context).pop((
                              reasonCode: _selectedReason!,
                              notes: _notesController.text.trim().isEmpty
                                  ? null
                                  : _notesController.text.trim(),
                            )),
                      child: const Text('Confirm Cancellation'),
                    ),
                  ),
                  const SizedBox(height: Space.s2),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      key: const Key('cancel_dismiss_button'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(
                          double.infinity,
                          DesignTokens.targetMinimum,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('Keep Job'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
