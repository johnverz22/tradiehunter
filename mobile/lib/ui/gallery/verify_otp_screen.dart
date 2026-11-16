// GENERATED from ast/screens.mjs (id: verify_otp, route: /verify-email). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class VerifyOtpScreen extends StatelessWidget {
  const VerifyOtpScreen({super.key});

  static const String route = '/verify-email';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(title: 'Verify your email'),
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s3,
        children: [
          const SizedBox(height: 16.0),
          THText('Enter the 6-digit code', style: THTextStyle.h1),
          const SizedBox(height: 6.0),
          THText(
            'We sent a code to mere@example.co.nz.',
            style: THTextStyle.body,
            tone: THTone.soft,
          ),
          const SizedBox(height: 24.0),
          THOtp(count: 6, value: '482'),
          const SizedBox(height: 16.0),
          THText(
            'Resend code in 0:42',
            style: THTextStyle.meta,
            tone: THTone.soft,
            align: TextAlign.center,
          ),
          const Spacer(),
          THButton(
            label: 'Verify',
            kind: THButtonKind.primary,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
