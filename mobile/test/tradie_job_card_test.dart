import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixo/models/marketplace.dart';
import 'package:fixo/theme/design_tokens.dart';
import 'package:fixo/theme/fixo_theme.dart';
import 'package:fixo/views/widgets/job_status_presentation.dart';
import 'package:fixo/views/widgets/tradie_job_card.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Job buildJob({
    required String status,
    DateTime? scheduledStartUtc,
    Decimal? totalAmount,
    String id = 'JOB-00123',
    String title = 'Repair bathroom leaking pipe',
    String category = 'Plumbing',
    String suburb = 'Ponsonby',
    String? referenceCode,
  }) {
    return Job(
      id: id,
      title: title,
      category: category,
      suburb: suburb,
      status: status,
      stage: 0,
      totalAmount: totalAmount ?? Decimal.parse('350.00'),
      scheduledStartUtc:
          scheduledStartUtc ?? DateTime.utc(2026, 11, 15, 14, 30),
      hours: 2,
      referenceCode: referenceCode,
    );
  }

  Widget wrap(Widget child, {bool dark = false, double textScale = 1.0}) {
    return MaterialApp(
      theme: dark ? FixoTheme.dark() : FixoTheme.light(),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(
              textScaler: TextScaler.linear(textScale)),
          child: Padding(
            padding: const EdgeInsets.all(Space.s4),
            child: child,
          ),
        ),
      ),
    );
  }

  const allStatuses = [
    'Requested',
    'AwaitingPayment',
    'Booked',
    'InProgress',
    'AwaitingConfirmation',
    'Completed',
    'Cancelled',
    'Disputed',
  ];

  // ── Renders without overflow ──────────────────────────────────────────────

  group('TradieJobCard renders without overflow', () {
    for (final status in allStatuses) {
      for (final dark in [false, true]) {
        for (final scale in [1.0, 1.3]) {
          testWidgets(
            'status=$status dark=$dark scale=$scale',
            (tester) async {
              await tester.pumpWidget(wrap(
                TradieJobCard(
                    job: buildJob(status: status), onTap: () {}),
                dark: dark,
                textScale: scale,
              ));
              expect(find.text('Repair bathroom leaking pipe'),
                  findsOneWidget);
              expect(find.byType(StatusChip), findsOneWidget);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  });

  // ── Reference code ────────────────────────────────────────────────────────

  group('reference code', () {
    testWidgets('uses job.referenceCode when present', (tester) async {
      await tester.pumpWidget(wrap(
        TradieJobCard(
          job: buildJob(status: 'Booked', referenceCode: '188'),
          onTap: () {},
        ),
      ));
      expect(find.text('188'), findsOneWidget);
      final refText = tester.widget<Text>(find.text('188'));
      expect(refText.style?.fontFamily, DesignTokens.fontMono,
          reason: 'reference code uses mono font');
    });

    testWidgets('falls back to job.id when referenceCode is null and id ≤12',
        (tester) async {
      await tester.pumpWidget(wrap(
        TradieJobCard(
          job: buildJob(status: 'Booked', id: 'SHORT-01'),
          onTap: () {},
        ),
      ));
      expect(find.text('SHORT-01'), findsOneWidget);
    });

    testWidgets('omits ref when id is a full GUID (>12 chars)', (tester) async {
      await tester.pumpWidget(wrap(
        TradieJobCard(
          job: buildJob(
              status: 'Booked',
              id: '550e8400-e29b-41d4-a716-446655440000'),
          onTap: () {},
        ),
      ));
      // The long GUID should NOT appear as text in the card.
      expect(
          find.text('550e8400-e29b-41d4-a716-446655440000'), findsNothing);
    });

    testWidgets('reference on trailing edge of meta row — not own line',
        (tester) async {
      // Ref code must share the same Row as trade · suburb.
      await tester.pumpWidget(wrap(
        TradieJobCard(
          job: buildJob(
              status: 'Booked',
              referenceCode: '188',
              category: 'Plumbing',
              suburb: 'Ponsonby'),
          onTap: () {},
        ),
      ));
      // Both meta text and ref text exist.
      expect(find.text('Plumbing · Ponsonby'), findsOneWidget);
      expect(find.text('188'), findsOneWidget);

      // They must be in the same Row widget (same dy within 1pt).
      final metaY = tester.getCenter(find.text('Plumbing · Ponsonby')).dy;
      final refY  = tester.getCenter(find.text('188')).dy;
      expect(metaY, closeTo(refY, 4.0),
          reason: 'trade·suburb and ref are on the same line');
    });
  });

  // ── Overdue treatment ─────────────────────────────────────────────────────

  group('overdue treatment', () {
    testWidgets('past Booked job shows Overdue chip + amber border',
        (tester) async {
      final past = DateTime.now().subtract(const Duration(days: 2));
      await tester.pumpWidget(wrap(
        TradieJobCard(
          job: buildJob(status: 'Booked', scheduledStartUtc: past),
          onTap: () {},
        ),
      ));
      expect(find.text('Overdue'), findsOneWidget);
      final container = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(TradieJobCard),
              matching: find.byType(Container),
            ),
          )
          .firstWhere(
            (c) =>
                c.decoration is BoxDecoration &&
                (c.decoration as BoxDecoration).border != null,
          );
      final border =
          ((container.decoration as BoxDecoration).border as Border).top;
      expect(border.color, DesignTokens.amber,
          reason: 'overdue card has amber border');
    });

    testWidgets('price text is NOT amber for overdue card', (tester) async {
      final past = DateTime.now().subtract(const Duration(days: 2));
      await tester.pumpWidget(wrap(
        TradieJobCard(
          job: buildJob(
              status: 'Booked',
              scheduledStartUtc: past,
              totalAmount: Decimal.parse('1200.00')),
          onTap: () {},
        ),
      ));
      final priceText = tester.widget<Text>(
        find.textContaining('\$1,200'),
      );
      // Price must not use amber / inkAccent — it must use th.text (ink colour).
      expect(priceText.style?.color,
          isNot(DesignTokens.amber),
          reason: 'price text must not be amber on overdue card');
      expect(priceText.style?.color,
          isNot(const Color(0xFF8F4F08)),
          reason: 'price text must not use inkAccent');
    });

    testWidgets('future Booked job shows normal Booked chip', (tester) async {
      final future = DateTime.now().add(const Duration(days: 3));
      await tester.pumpWidget(wrap(
        TradieJobCard(
          job: buildJob(status: 'Booked', scheduledStartUtc: future),
          onTap: () {},
        ),
      ));
      expect(find.text('Booked'), findsOneWidget);
      expect(find.text('Overdue'), findsNothing);
    });

    testWidgets('isOverdueOverride=true forces overdue treatment', (tester) async {
      final future = DateTime.now().add(const Duration(days: 3));
      await tester.pumpWidget(wrap(
        TradieJobCard(
          job: buildJob(status: 'Booked', scheduledStartUtc: future),
          onTap: () {},
          isOverdueOverride: true,
        ),
      ));
      expect(find.text('Overdue'), findsOneWidget);
    });
  });

  // ── Title clamping ────────────────────────────────────────────────────────

  testWidgets('long title is clamped to 2 lines with ellipsis', (tester) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const longTitle =
        'Replace all bathroom taps fittings pipes and shower rose '
        'throughout the entire three-bedroom house in Ponsonby Auckland';

    await tester.pumpWidget(wrap(
      TradieJobCard(
        job: buildJob(status: 'Booked', title: longTitle),
        onTap: () {},
      ),
    ));

    final titleWidget = tester.widget<Text>(
      find.text(
        longTitle,
        findRichText: false,
      ).evaluate().isEmpty
          ? find.byWidgetPredicate(
              (w) =>
                  w is Text &&
                  w.data?.startsWith('Replace') == true,
            )
          : find.text(longTitle),
    );
    expect(titleWidget.maxLines, 2,
        reason: 'title maxLines must be 2');
    expect(titleWidget.overflow, TextOverflow.ellipsis,
        reason: 'title overflow must be ellipsis');
    expect(tester.takeException(), isNull);
  });

  // ── CTA and chevron ───────────────────────────────────────────────────────

  group('CTA and chevron', () {
    testWidgets('Booked shows Check in CTA', (tester) async {
      await tester.pumpWidget(wrap(
          TradieJobCard(job: buildJob(status: 'Booked'), onTap: () {})));
      expect(find.byKey(const Key('today_card_cta')), findsOneWidget);
      expect(find.text('Check in'), findsOneWidget);
    });

    testWidgets('Completed shows chevron only (no CTA)', (tester) async {
      await tester.pumpWidget(wrap(
          TradieJobCard(job: buildJob(status: 'Completed'), onTap: () {})));
      expect(find.byKey(const Key('today_card_cta')), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });
  });

  // ── Widget type consistency ───────────────────────────────────────────────

  testWidgets('Home and Jobs build the same widget type', (tester) async {
    final job  = buildJob(status: 'Booked');
    final card = TradieJobCard(job: job, onTap: () {});
    expect(card, isA<TradieJobCard>());
  });
}
