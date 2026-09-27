import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/fixo_cards.dart' show FixoBadgeKind, StatusBadge, JobStepper;

/// Modernized replacement for the ad-hoc `InkWell(child: FixoCard(...))`
/// blocks repeated across `homeowner_home_screen.dart`,
/// `tradie_home_screen.dart` and `jobs_list_screen.dart`.
///
/// This widget is intentionally **data-in, callback-out**: it takes plain
/// values (strings/enums) rather than importing the `Job` model type from
/// `viewmodels/jobs_viewmodel.dart`, since that file wasn't part of this
/// refactor pass. At each call site you keep reading straight off the
/// existing `job` object from `jobsViewModelProvider` — nothing about the
/// ViewModel or its fields changes, only how the row is laid out. E.g.:
///
/// ```dart
/// ModernJobCard(
///   title: job.title,
///   referenceId: job.id,
///   category: job.category,
///   location: job.suburb, // no ZIP/postal field exists on Job today —
///                          // this chip renders whatever location string
///                          // the ViewModel provides (suburb/address).
///   statusLabel: job.status,
///   statusKind: _kindFor(job.status),
///   stage: job.stage,               // omit for screens with no stepper
///   isUrgent: job.urgency == 'Urgent',
///   onTap: () => context.push('/chat/${job.id}'),
/// )
/// ```
class ModernJobCard extends StatelessWidget {
  final String title;
  final String? referenceId;
  final String category;

  /// Free-text location for this job — bind to whatever field your Job
  /// model exposes (suburb, address, or ZIP/postal code once added).
  final String location;

  final String statusLabel;
  final FixoBadgeKind statusKind;

  /// 0-based stepper stage (Requested → Matched → Confirmed → Complete).
  /// Pass null to omit the stepper (e.g. tradie "incoming request" cards).
  final int? stage;

  final bool isUrgent;
  final String? timestampLabel;
  final VoidCallback onTap;

  const ModernJobCard({
    super.key,
    required this.title,
    this.referenceId,
    required this.category,
    required this.location,
    required this.statusLabel,
    required this.statusKind,
    this.stage,
    this.isUrgent = false,
    this.timestampLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? DesignTokens.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? DesignTokens.paperLineDark : DesignTokens.paperLineLight,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(label: statusLabel, kind: statusKind),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (referenceId != null)
                    _Chip(
                      icon: Icons.tag_rounded,
                      label: referenceId!,
                      mono: true,
                    ),
                  _Chip(icon: Icons.build_outlined, label: category),
                  _Chip(icon: Icons.location_on_outlined, label: location),
                  if (isUrgent)
                    const StatusBadge(label: 'URGENT', kind: FixoBadgeKind.urgent),
                ],
              ),
              if (timestampLabel != null) ...[
                const SizedBox(height: 8),
                Text(
                  timestampLabel!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              if (stage != null) ...[
                const SizedBox(height: 14),
                JobStepper(activeStage: stage!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool mono;

  const _Chip({required this.icon, required this.label, this.mono = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? DesignTokens.brand100Dark : DesignTokens.brand100Light;
    final fg = isDark ? DesignTokens.inkDark : DesignTokens.brand900;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: mono ? DesignTokens.fontMono : DesignTokens.fontBody,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
