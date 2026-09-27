import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/fixo_buttons.dart';
import '../widgets/abstract_onboarding_background.dart';

/// Mockup 02-onboarding, restyled: wordmark header, organic mesh
/// background behind the illustration, H1 + body copy, amber dot
/// indicator, amber Next + ghost Skip.
///
/// NOTE ON MVVM: the provided project archive has no
/// `OnboardingViewModel` — the original `onboarding_screen.dart` manages
/// its `PageController` and `_currentPage` as plain `State`, with no
/// Provider/Riverpod/Bloc involved. Per the "preserve all existing logic
/// and state variables" constraint, this view keeps that exact same
/// local-state shape rather than introducing a ViewModel that doesn't
/// exist in the codebase. If you do have (or plan to add) an
/// `OnboardingViewModel` elsewhere, swap the two marked lines below for
/// `ref.watch/read(onboardingViewModelProvider)` calls — nothing else
/// in this file needs to change.
///
/// This class keeps the original name `OnboardingScreen` so existing
/// `go_router` routes that import `onboarding_screen.dart` keep working
/// if you replace that file's contents with this one (or update the
/// import path to `views/onboarding/onboarding_view.dart`).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // ── Preserved exactly from the original screen ──────────────────────
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
      title: 'Get matched fast',
      body: 'We find verified tradies near you and notify them instantly.',
    ),
    (
      asset: 'assets/illustrations/onboarding_chat.png',
      title: 'Chat and get it sorted',
      body: 'Confirm the job, chat directly, and leave a review when it’s done.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: FixoWordmark(fontSize: 24),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (p) => setState(() => _currentPage = p),
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          // Rigid brand-100 square container replaced with
                          // a soft, organic blurred-mesh background.
                          // BoxFit.contain is preserved: the art bleeds to
                          // all four edges, so cover would still clip it.
                          child: AbstractOnboardingBackground(
                            seed: index,
                            child: Image.asset(
                              slide.asset,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                        child: Text(
                          slide.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: Text(
                          slide.body,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                        child: Row(
                          children: List.generate(
                            _slides.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: i == _currentPage ? 22 : 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(100),
                                color: i == _currentPage
                                    ? DesignTokens.amber
                                    : (isDark ? DesignTokens.brand100Dark : DesignTokens.brand100Light),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FixoPrimaryButton(
                    label: _currentPage == _slides.length - 1 ? 'Get Started' : 'Next',
                    onPressed: () {
                      if (_currentPage == _slides.length - 1) {
                        context.go('/auth');
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      }
                    },
                  ),
                  TextButton(
                    onPressed: () => context.go('/auth'),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
