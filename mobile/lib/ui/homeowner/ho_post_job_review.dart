import 'package:flutter/material.dart';

import '../../viewmodels/jobs_viewmodel.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import 'ho_post_job_mapper.dart';

class HoPostJobReviewCard extends StatelessWidget {
  const HoPostJobReviewCard({super.key, required this.state});

  final PostJobState state;

  @override
  Widget build(BuildContext context) {
    final rows = thReviewRows(state);
    return THCard(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  THText(
                    thReviewSummaryTitle(state.jobType),
                    style: THTextStyle.title,
                  ),
                  const SizedBox(height: Space.s1),
                  THText(
                    thReviewPricingNote(state.jobType),
                    style: THTextStyle.meta,
                    tone: THTone.soft,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.s3),
            THIcon(
              state.isProject
                  ? Icons.request_quote_outlined
                  : Icons.receipt_long_outlined,
              size: Sizes.iconLg,
              tone: THTone.accent,
            ),
          ],
        ),
        const SizedBox(height: Space.s2),
        for (var i = 0; i < rows.length; i++)
          THKeyValue(
            rows[i].label,
            rows[i].kind == ThReviewRowKind.when
                ? _formatWhen(context, rows[i].when!)
                : rows[i].value,
            tone: rows[i].placeholder ? THTone.soft : THTone.base,
            divider: i > 0,
          ),
        const SizedBox(height: Space.s3),
        THText(
          thReviewMaterialsNote,
          style: THTextStyle.meta,
          tone: THTone.soft,
        ),
      ],
    );
  }

  String _formatWhen(BuildContext context, DateTime value) {
    final localizations = MaterialLocalizations.of(context);
    final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value));
    return '${localizations.formatFullDate(value)} · $time';
  }
}
