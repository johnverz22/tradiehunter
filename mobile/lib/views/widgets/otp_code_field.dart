import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/design_tokens.dart';

/// Six-box one-time-code input (P1-03 email OTP).
///
/// Presentation-only and ViewModel-agnostic: it owns no auth state, just the
/// typed digits. A single hidden [TextField] holds the value so the platform
/// keyboard, autofill and paste all behave like a normal text field; the six
/// boxes are painted on top of it and reflect [controller].
///
/// The box count is fixed at 6 to match the backend code length
/// (`RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6")`).
///
/// ```dart
/// final controller = TextEditingController();
/// OtpCodeField(
///   controller: controller,
///   onCompleted: (code) => submit(code),
/// );
/// ```
class OtpCodeField extends StatefulWidget {
  static const int length = 6;

  final TextEditingController controller;
  final bool enabled;

  /// Fired on every keystroke with the current (partial or full) code.
  final ValueChanged<String>? onChanged;

  /// Fired when the last box is filled, with the complete code.
  final ValueChanged<String>? onCompleted;

  const OtpCodeField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onChanged,
    this.onCompleted,
  });

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onValueChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onValueChanged);
    _focusNode.dispose();
    super.dispose();
  }

  String _previousCode = '';

  @override
  void didUpdateWidget(covariant OtpCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onValueChanged);
      widget.controller.addListener(_onValueChanged);
      _previousCode = widget.controller.text;
    }
  }

  void _onFocusChanged() => setState(() {});

  void _onValueChanged() {
    final code = widget.controller.text;
    if (code == _previousCode) return;
    _previousCode = code;
    setState(() {});
    widget.onChanged?.call(code);
    if (code.length == OtpCodeField.length && widget.enabled) {
      widget.onCompleted?.call(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lineColor = isDark
        ? DesignTokens.paperLineDark
        : DesignTokens.paperLineLight;
    final code = widget.controller.text;

    return Semantics(
      label: 'One-time code, ${OtpCodeField.length} digits',
      textField: true,
      child: Stack(
        children: [
          // Real input, sized to fill the row and painted transparent. The
          // boxes below render the value, so this must stay on top to keep
          // the caret and selection alive.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              alwaysIncludeSemantics: true,
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                showCursor: false,
                maxLength: OtpCodeField.length,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          // Purely visual mirror of the hidden field — IgnorePointer so
          // every tap falls through to the real input underneath.
          ExcludeSemantics(
            child: IgnorePointer(
              child: Row(
                children: List.generate(OtpCodeField.length, (i) {
                  final digit = i < code.length ? code[i] : '';
                  final isFilled = digit.isNotEmpty;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: i == OtpCodeField.length - 1 ? 0 : 4,
                      ),
                      child: _OtpBox(
                        digit: digit,
                        isFilled:
                            isFilled ||
                            (_focusNode.hasFocus && i == code.length),
                        lineColor: lineColor,
                        accentColor: theme.colorScheme.primary,
                        inkColor: theme.colorScheme.onSurface,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final String digit;
  final bool isFilled;
  final Color lineColor;
  final Color accentColor;
  final Color inkColor;

  const _OtpBox({
    required this.digit,
    required this.isFilled,
    required this.lineColor,
    required this.accentColor,
    required this.inkColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(vertical: Space.s3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isFilled
            ? accentColor.withValues(alpha: Alpha.tint)
            : Colors.transparent,
        border: Border.all(
          color: isFilled ? accentColor : lineColor,
          width: isFilled ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
      ),
      child: Text(
        digit,
        style: TextStyle(
          fontFamily: DesignTokens.fontBody,
          fontSize: DesignTokens.fontSizeH2,
          fontWeight: FW.semibold,
          color: inkColor,
        ),
      ),
    );
  }
}
