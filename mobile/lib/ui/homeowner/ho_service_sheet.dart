import 'package:flutter/material.dart';

import '../../models/marketplace.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

/// Service picker sheet. The mockup only draws a chevron field, so the sheet
/// is composed from TH* primitives (`needs-design`, G-8).
Future<ServiceOption?> showThServiceSheet(
  BuildContext context, {
  required List<ServiceOption> services,
  ServiceOption? selected,
}) {
  final theme = Theme.of(context);
  return showModalBottomSheet<ServiceOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Theme(
        data: theme,
        child: Builder(
          builder: (ctx) {
            final c = ctx.th;
            return FractionallySizedBox(
              heightFactor: 0.6,
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(Radii.sheet),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Sizes.gutter,
                          Space.s4,
                          Sizes.gutter,
                          Space.s2,
                        ),
                        child: THText(
                          'Choose a service',
                          style: THTextStyle.title,
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            Sizes.gutter,
                            Space.s1,
                            Sizes.gutter,
                            Space.s4,
                          ),
                          itemCount: services.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: Space.s2),
                          itemBuilder: (ctx, index) {
                            final service = services[index];
                            return Semantics(
                              button: true,
                              label: service.name,
                              child: InkWell(
                                onTap: () => Navigator.pop(ctx, service),
                                borderRadius: BorderRadius.circular(Radii.card),
                                child: THListRow(
                                  icon: Icons.handyman_outlined,
                                  title: service.name,
                                  subtitle: service.category,
                                  badge: selected?.id == service.id
                                      ? 'Selected'
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
