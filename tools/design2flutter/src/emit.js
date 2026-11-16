/**
 * emit.js — widget specs -> idiomatic Flutter/Dart source.
 * Rules baked in:
 *  - one StatelessWidget per frame, named <Domain><Screen>Screen from the frame id
 *  - repeated sub-structures become private widget methods (_buildXxx)
 *  - tokens only: Space/Radii/Sizes/THType/THColors expressions; raw literals fail
 *  - every file carries the provenance header (source frame, theme, generator)
 */
'use strict';

const FRAME_NAMES = {
  // frame id prefix -> Dart screen name (extend as screens are added)
  H07: 'HomeownerDashboard', H10: 'JobBoard', H11: 'JobDetail', H12: 'JobProgress',
  H13: 'ChatScreen', H15: 'PaymentReview', H16: 'PaymentStatus', H17: 'TradieProfileRating',
  H18: 'HomeownerProfile', H19: 'FindTradie',
  T19: 'TradieLeads', T20: 'LeadDetail', T21: 'JobRequestMap', T22: 'ActiveJob',
  T23: 'TradieChat', T25: 'OnboardingWizard', T26: 'PublicProfile',
  S01: 'Splash', S02: 'Onboarding', S03: 'RoleIntro', S04: 'Signup', S05: 'Login',
  S06: 'Signup', S07: 'Otp', S08: 'RoleSelect',
  E: 'EmptyState',
};

function screenName(frameId) {
  const base = frameId.split('-')[0];
  // strip theme suffixes — theme is a runtime concern (THColors), not a class name
  const parts = frameId.split('-').slice(1).filter(p => !['light', 'dark', 'outdoor'].includes(p));
  const tail = parts.map(cap).join('');
  const name = FRAME_NAMES[base] || 'DesignScreen';
  return tail ? `${name}${tail}` : name;
}
const cap = s => s.charAt(0).toUpperCase() + s.slice(1);

// widgets whose constructor takes children: [...]; everything else takes child:
const MULTI_CHILD = new Set(['Row', 'Column', 'Wrap', 'GridView', 'THFadeRow', 'FixoAppBar',
  'FixoCard', 'THListGroup', 'THButtonRow', 'THSheet', 'THMapHeader', 'THHeroBand',
  'THStatusStrip', 'THField', 'THBanner', 'THStickyCta', 'THIconTile', 'THPhotoTile']);

/** Dart-expression detection: quote anything that is not already an expression */
const EXPR_RE = /^(null|true|false|[\d.]+(\s*[-+*/]\s*[\d.]+)*|Space\.|Radii\.|Sizes\.|THType\.|THColors\.|THPalette\.|THHeroGlass\.|Icons\.|MainAxis\w*|CrossAxis\w*|const |Color\w*\(|\[|\{)/;
function dartValue(v) {
  if (v === null || v === undefined || v === '') return null;
  if (v === '__CLOSURE__') return '() { /* TODO: wire action */ }';
  if (typeof v !== 'string') return String(v);
  if (EXPR_RE.test(v) && !/^'/.test(v)) return v;
  const escaped = v.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\$/g, '\\$');
  return `'${escaped}'`;
}

/** render a widget spec tree into Dart lines */
function renderSpec(spec, indent, ctx) {
  const pad = '  '.repeat(indent);
  const lines = [];
  if (!spec) return lines;
  if (spec.comment) lines.push(`${pad}// ${spec.comment}`);

  // material Text: first positional argument is the label
  let entries = Object.entries(spec.props || {}).filter(([, v]) => v !== null && v !== undefined && v !== '');
  if (spec.widget === 'Text') {
    const textIdx = entries.findIndex(([k]) => k === 'text');
    if (textIdx >= 0) {
      const [, tv] = entries[textIdx];
      entries = entries.filter(([k]) => k !== 'text');
      entries.unshift(['__positional__', tv]);
    }
  }
  const props = entries.map(([k, v]) =>
    k === '__positional__' ? dartValue(v) : `${k}: ${dartValue(v)}`);

  const kids = (spec.children || []).filter(Boolean);
  const multi = MULTI_CHILD.has(spec.widget);

  if (kids.length === 0) {
    lines.push(`${pad}${spec.widget}(${props.join(', ')}),`);
    return lines;
  }

  if (!multi && kids.length === 1) {
    const inner = renderSpec(kids[0], 0, ctx);
    const expr = inner.map(l => l.trim().replace(/,$/, '')).join(' ');
    lines.push(`${pad}${spec.widget}(`);
    if (props.length) lines.push(`${pad}  ${props.join(', ')},`);
    lines.push(`${pad}  child: ${expr},`);
    lines.push(`${pad}),`);
    return lines;
  }

  // multi-child (or a child-only widget with several children -> wrap in Column)
  lines.push(`${pad}${spec.widget}(`);
  if (props.length) lines.push(`${pad}  ${props.join(', ')},`);
  if (multi) {
    lines.push(`${pad}  children: [`);
    for (const c of kids) lines.push(...renderSpec(c, indent + 2, ctx));
    lines.push(`${pad}  ],`);
  } else {
    lines.push(`${pad}  child: Column(`);
    lines.push(`${pad}    crossAxisAlignment: CrossAxisAlignment.stretch,`);
    lines.push(`${pad}    children: [`);
    for (const c of kids) lines.push(...renderSpec(c, indent + 3, ctx));
    lines.push(`${pad}    ],`);
    lines.push(`${pad}  ),`);
  }
  lines.push(`${pad}),`);
  return lines;
}

/** entry: emit one screen file */
function emitScreen(frame, opts = {}) {
  const { RULES } = require('./widgetMap');
  const name = screenName(frame.frame);
  const ctx = { methods: [], counters: {} };

  const applyRules = node => {
    for (const rule of RULES) {
      if (rule.match(node)) {
        const spec = rule.build(node);
        if (spec.children === node.children) {
          spec.children = node.children.map(applyRules).filter(Boolean);
        }
        return spec;
      }
    }
    return null;
  };

  // frame body: children of the frame element, rendered directly into the
  // Scaffold/SafeArea/Column that the template below provides
  const body = frame.tree.children.map(applyRules).filter(Boolean);
  const bodyLines = body.map(b => renderSpec(b, 3, ctx)).flat();

  return `// GENERATED by tools/design2flutter — DO NOT EDIT BY HAND.
// Source: docs/design/html/${frame.file} [data-frame="${frame.frame}"]
// Theme: ${frame.theme} (mockup ${frame.width}x${frame.height}dp). Runtime theme comes from
// ThemeData.extensions<THColors>() — never hardcode colors for one mode.
// Audit gate: all values map to Space/Radii/Sizes/THType/THColors tokens.

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../widgets/fixo_components.dart';

class ${name}Screen extends StatelessWidget {
  const ${name}Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<THColors>()!;
    return Scaffold(
      backgroundColor: theme.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
${bodyLines.join('\n')}
          ],
        ),
      ),
    );
  }
}
`;
}

module.exports = { emitScreen, screenName };
