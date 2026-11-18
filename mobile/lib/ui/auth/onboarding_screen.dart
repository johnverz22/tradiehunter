// ThOnboardingScreen: v2 onboarding (migration plan 3.2, id `onboarding`).
//
// Hand-owned port of views/onboarding/onboarding_view.dart. Same three
// slides and assets (copy aligned to the mockup, S-03), same PageView flow,
// same Semantics contract ('Step N of 3' on the indicator), same navigation
// (Skip / last page → /auth). Layout follows the mockup: no header, with the
// dots, Next and a ghost Skip stacked at the foot. The animated abstract
// background is replaced by a static token-styled radial halo: v2 has no
// background mockup yet and a static illustration is reduce-motion-safe by
// construction.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';

class ThOnboardingScreen extends ConsumerStatefulWidget {
  const ThOnboardingScreen({super.key});

  @override
  ConsumerState<ThOnboardingScreen> createState() => _ThOnboardingScreenState();
}

class _ThOnboardingScreenState extends ConsumerState<ThOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Slide 1 is the mockup copy verbatim; 2 and 3 follow the same voice and
  // only state what the app does (no fee, badge or verification claims).
  static const _slides = [
    (
      asset: 'assets/illustrations/onboarding_describe.png',
      title: 'Post a job in minutes',
      body: 'Describe what you need, choose a local tradie, and pay only when the work is approved.',
    ),
    (
      asset: 'assets/illustrations/onboarding_match.png',
      title: 'Choose with confidence',
      body: 'Compare rates, credentials and reviews before you decide. Rates always include GST.',
    ),
    (
      asset: 'assets/illustrations/onboarding_chat.png',
      title: 'Chat and get it sorted',
      body: 'Follow job updates and message your tradie in one place. Leave a review when the work is done.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: Builder(
        builder: (context) {
          final c = context.th;
          return Scaffold(
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: Space.s7),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (p) => setState(() => _currentPage = p),
                      itemCount: _slides.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final slide = _slides[index];
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.s6,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Illustration inside a token-styled radial
                              // halo (needs-design stand-in for the v1
                              // animated abstract background).
                              Container(
                                height:
                                    MediaQuery.of(context).size.height * 0.42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [c.tintBrand, Colors.transparent],
                                  ),
                                ),
                                child: Image.asset(
                                  slide.asset,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                              const SizedBox(height: Space.s6),
                              Text(
                                slide.title,
                                style: THType.h2.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: c.text,
                                ),
                              ),
                              const SizedBox(height: Space.s3),
                              Text(
                                slide.body,
                                style: THType.body.copyWith(color: c.textSoft),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      Space.s6,
                      Space.s4,
                      Space.s6,
                      Space.s4 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: Space.s2,
                      children: [
                        // Contract: the indicator announces the step.
                        Semantics(
                          label:
                              'Step ${_currentPage + 1} of ${_slides.length}',
                          child: ExcludeSemantics(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < _slides.length; i++)
                                  AnimatedContainer(
                                    duration: THDurations.fast,
                                    height: Space.s2_5,
                                    width: i == _currentPage
                                        ? Space.s8
                                        : Space.s2_5,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: Space.s1,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        Radii.pill,
                                      ),
                                      color: i == _currentPage
                                          ? c.accent
                                          : c.track,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: Space.s3),
                        THButton(
                          label: _currentPage == _slides.length - 1
                              ? 'Get started'
                              : 'Next',
                          onPressed: () {
                            if (_currentPage == _slides.length - 1) {
                              context.go('/auth');
                            } else {
                              _pageController.nextPage(
                                duration: THMotion.duration(
                                  context,
                                  THMotion.onboardingPage,
                                ),
                                curve: THMotion.curve(
                                  context,
                                  THMotion.onboardingCurve,
                                ),
                              );
                            }
                          },
                        ),
                        THButton(
                          label: 'Skip',
                          kind: THButtonKind.ghost,
                          onPressed: () => context.go('/auth'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
