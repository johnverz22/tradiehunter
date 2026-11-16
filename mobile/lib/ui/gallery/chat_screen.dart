// GENERATED from ast/screens.mjs (id: chat, route: /chat/:jobId). Do not edit by hand:
// change the AST and re-run `node tools/build.mjs`.
import 'package:flutter/material.dart';

import '../design/th_tokens.dart';
import '../design/th_widgets.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  static const String route = '/chat/:jobId';

  @override
  Widget build(BuildContext context) {
    return THScaffold(
      appBar: THAppBar(title: 'Aroha Plumbing', subtitle: 'Leaking kitchen tap'),
      stickyBar: THStickyBar(children: [
        Expanded(
          child: THField(value: 'Message', placeholder: true),
        ),
        THIconButton(icon: Icons.send_rounded, kind: THButtonKind.primary, semanticLabel: 'send', onPressed: () {}),
      ]),
      scrollable: true,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s3,
          children: [
          THBubble('Kia ora Mere, I’ll be there around 10.', mine: false, time: '8:41 am'),
          THBubble('Perfect, the gate code is 4471.', mine: true, time: '8:44 am'),
          THBubble('Thanks. Found a worn cartridge, sending an extra cost request now.', mine: false, time: '9:20 am'),
          THCard(
            tone: THCardTone.accent, padding: Space.s3,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, spacing: Space.s2_5,
                children: [
                  THIcon(Icons.check_rounded, tone: THTone.ok),
                  Expanded(
                    child: THText('Extra cost \$48.50 approved by Mere', style: THTextStyle.meta),
                  ),
                ],
              ),
            ],
          ),
          THBubble('Approved, thanks!', mine: true, time: '9:24 am'),
          ],
        ),
    );
  }
}
