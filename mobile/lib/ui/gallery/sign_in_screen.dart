// GENERATED from ast/screens.mjs (id: sign_in, route: /login). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  static const String route = '/login';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s3,
        children: [
          const SizedBox(height: 12.0),
          THWordmark(large: false),
          const SizedBox(height: 28.0),
          THText('Welcome back', style: THTextStyle.h1),
          const SizedBox(height: 4.0),
          THText(
            'Sign in to manage your jobs.',
            style: THTextStyle.body,
            tone: THTone.soft,
          ),
          const SizedBox(height: 20.0),
          THField(
            label: 'EMAIL',
            value: 'mere@example.co.nz',
            icon: Icons.mail_outline_rounded,
          ),
          THField(
            label: 'PASSWORD',
            value: '••••••••••',
            icon: Icons.lock_outline_rounded,
            trailing: Icons.visibility_outlined,
          ),
          THText(
            'Forgot password?',
            style: THTextStyle.title,
            tone: THTone.brand,
            align: TextAlign.end,
            size: 13.0,
          ),
          const SizedBox(height: 8.0),
          THButton(
            label: 'Sign in',
            kind: THButtonKind.primary,
            onPressed: () {},
          ),
          THDivider(label: 'or'),
          THButton(
            label: 'Continue with Google',
            kind: THButtonKind.secondary,
            icon: Icons.public_rounded,
            onPressed: () {},
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: Space.s1,
            children: [
              THText('New here?', style: THTextStyle.body, tone: THTone.soft),
              THText(
                'Create account',
                style: THTextStyle.title,
                tone: THTone.brand,
                size: 15.0,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
