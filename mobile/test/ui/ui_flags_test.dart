// Phase 2.10: per-screen v2 flag resolution.
import 'package:fixo/ui/gallery/screens.dart';
import 'package:fixo/ui/ui_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to v1 when nothing is enabled', () {
    expect(resolveV2Screen('sign_in'), isFalse);
    expect(resolveV2Screen('sign_in', define: '   '), isFalse);
  });

  test('allowlist enables only the listed screens', () {
    const allow = {'sign_in', 'onboarding'};
    expect(resolveV2Screen('sign_in', allowlist: allow), isTrue);
    expect(resolveV2Screen('onboarding', allowlist: allow), isTrue);
    expect(resolveV2Screen('ho_home', allowlist: allow), isFalse);
  });

  test('UI_V2=all enables every screen', () {
    expect(resolveV2Screen('ho_home', define: 'all'), isTrue);
    expect(resolveV2Screen('anything', define: ' all '), isTrue);
  });

  test('UI_V2 accepts a comma-separated id list', () {
    expect(resolveV2Screen('sign_in', define: 'sign_in, splash'), isTrue);
    expect(resolveV2Screen('splash', define: 'sign_in, splash'), isTrue);
    expect(resolveV2Screen('ho_home', define: 'sign_in, splash'), isFalse);
  });

  test('the shipped allowlist only names real v2 screens', () {
    for (final id in v2Screens) {
      expect(
        thScreenBuilders.containsKey(id) || nonGalleryV2Screens.contains(id),
        isTrue,
        reason: '"$id" is not a v2 screen id',
      );
    }
  });

  test('non-gallery ids do not shadow gallery ids', () {
    // A non-gallery id must never also exist in the gallery registry, or
    // goldens would start rendering real screens with provider fakes.
    for (final id in nonGalleryV2Screens) {
      expect(thScreenBuilders.containsKey(id), isFalse, reason: id);
    }
  });

  test('isV2Screen is false for an unknown id by default', () {
    expect(isV2Screen('definitely_not_a_screen'), kUiV2Define == 'all');
  });
}
