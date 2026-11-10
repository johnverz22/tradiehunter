import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/design_tokens.dart';
import '../../widgets/fixo_buttons.dart';
import '../widgets/abstract_onboarding_background.dart';

/// Onboarding (mockup 02) — remodernized.
/// Same _pageController / _currentPage / slide data / navigation commands.
///
/// Class name kept as [OnboardingScreen] for router compatibility.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _slides = [
    (
      asset: 'assets/illustrations/onboarding_describe.png',
      title: 'Describe your problem',
      body: "Tell us what needs fixing and we'll connect you with the right local professionals.",
    ),
    (
      asset: 'assets/illustrations/onboarding_match.png',
      title: 'See credentials and reviews before you hire',
      body: 'Check profile credentials and reviews when choosing a tradie. We verify the documents your tradie provides.',
    ),
    (
      asset: 'assets/illustrations/onboarding_chat.png',
      title: 'Chat and get it sorted',
      body: 'Track job updates, chat directly and follow bank-transfer receipt review. Leave a review when the work is done.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final colors = Theme.of(context).extension<THColors>()!;
    return Scaffold(
      body: AbstractOnboardingBackground(
        seed: _currentPage,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.s6, Space.s7, Space.s6, Space.s2),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const FixoWordmark(fontSize: DesignTokens.fontSizeH1),
                    TextButton(
                      onPressed: () => context.go('/auth'),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.text,
                        minimumSize: const Size(Sizes.tapMin, Sizes.tapMin),
                        textStyle: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FW.semibold),
                      ),
                      child: const Text('Skip'),
                    ),
                  ],
                ),
              ),
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
                      padding: const EdgeInsets.symmetric(horizontal: Space.s6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Illustration floats inside a radial halo —
                          // replaces the old rigid brand-100 square container.
                          Container(
                            height: MediaQuery.of(context).size.height * 0.42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  DesignTokens.brand300.withValues(alpha: Alpha.gradient),
                                  Colors.transparent,
                                ],
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
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FW.bold,
                                  color: colors.text,
                                ),
                          ),
                          const SizedBox(height: Space.s3),
                          Text(
                            slide.body,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: colors.textSoft),
                          ),
                          const SizedBox(height: Space.s6),
                          // Animated pill indicator
                          Semantics(
                            label:
                                'Step ${_currentPage + 1} of ${_slides.length}',
                            child: ExcludeSemantics(
                              child: Row(
                                children: List.generate(
                                  _slides.length,
                                  (i) => AnimatedContainer(
                                    duration: FixoDurations.onboardingDot,
                                    height: Sizes.dot,
                                    width: i == _currentPage
                                        ? Sizes.dotActive
                                        : Sizes.dot,
                                    margin: const EdgeInsets.only(right: Space.s2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(Radii.pill),
                                      color: i == _currentPage
                                          ? DesignTokens.amber
                                          : colors.track,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(Space.s6, Space.s4, Space.s6, Space.s4 + bottom),
                child: FixoPrimaryButton(
                  label: _currentPage == _slides.length - 1
                      ? 'Get started'
                      : 'Next',
                  onPressed: () {
                    if (_currentPage == _slides.length - 1) {
                      context.go('/auth');
                    } else {
                      _pageController.nextPage(
                        duration: FixoDurations.debounce,
                        curve: Curves.easeInOutCubic,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
