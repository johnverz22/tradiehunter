// GENERATED from ast/screens.mjs (id: ho_jobs, route: /jobs). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class HoJobsScreen extends StatelessWidget {
  const HoJobsScreen({super.key});

  static const String route = '/jobs';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      dock: THDock(role: THDockRole.homeowner, active: THDockTab.jobs),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s3,
        children: [
          THText('My jobs', style: THTextStyle.h1),
          THSegmented(items: ['Active', 'Completed'], selected: 0),
          THCard(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: Space.s2,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 2.0,
                      children: [
                        THText('Leaking kitchen tap', style: THTextStyle.title),
                        THText(
                          'Aroha Plumbing',
                          style: THTextStyle.meta,
                          tone: THTone.soft,
                        ),
                      ],
                    ),
                  ),
                  THBadge('Pay now', kind: THBadgeKind.accent),
                ],
              ),
              const SizedBox(height: 12.0),
              THProgress(steps: 5, done: 4, current: true),
            ],
          ),
          THCard(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: Space.s2,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 2.0,
                      children: [
                        THText('Repaint hallway', style: THTextStyle.title),
                        THText(
                          'Waiting for Kiri Painters',
                          style: THTextStyle.meta,
                          tone: THTone.soft,
                        ),
                      ],
                    ),
                  ),
                  THBadge('Requested', kind: THBadgeKind.brand),
                ],
              ),
              const SizedBox(height: 12.0),
              THProgress(steps: 5, done: 1, current: true),
            ],
          ),
          THCard(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: Space.s2,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 2.0,
                      children: [
                        THText('Kitchen renovation', style: THTextStyle.title),
                        THText(
                          '2 of 3 quotes in',
                          style: THTextStyle.meta,
                          tone: THTone.soft,
                        ),
                      ],
                    ),
                  ),
                  THBadge('Quotes', kind: THBadgeKind.ok),
                ],
              ),
              const SizedBox(height: 12.0),
              THProgress(steps: 5, done: 1, current: true),
            ],
          ),
        ],
      ),
    );
  }
}
