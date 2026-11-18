import 'package:flutter/material.dart';

/// Mirrors a widget's `Key('…')` into the semantics tree as an
/// `identifier`, so out-of-process drivers (Maestro) can locate the same
/// elements that `find.byKey` finds in-process. Flutter `Key`s are not
/// visible outside the Dart isolate; `Semantics.identifier` is.
///
/// `identifier` is a semantics *property*, not a label — screen readers do
/// not announce it, so this never changes spoken output.
///
/// The shared `TH*` components call [thTestId] / [thTestIdWrap] from their
/// `build` methods, which keeps the identifier string identical to the Key
/// string by construction (E2E realignment plan E3).

/// Returns the identifier for [key] when it is a `ValueKey<String>`
/// (what `Key('login_button')` produces), else null.
String? thTestId(Key? key) => key is ValueKey<String> ? key.value : null;

/// Explicit semantics identifier wrapper for out-of-process drivers (Maestro).
/// Wraps [child] in a non-container [Semantics] node with [identifier].
class THTestId extends StatelessWidget {
  const THTestId({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(identifier: id, container: false, child: child);
  }
}

/// Convenience extension to wrap any widget in a [THTestId].
extension THTestIdExtension on Widget {
  Widget testId(String id) => THTestId(id: id, child: this);
}

/// Wraps [child] in `Semantics(identifier:, container: false)` when [key] carries a string
/// id; returns [child] unchanged otherwise.
Widget thTestIdWrap(Widget child, Key? key) {
  final id = thTestId(key);
  return id == null
      ? child
      : Semantics(identifier: id, container: false, child: child);
}
