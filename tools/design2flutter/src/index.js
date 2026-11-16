#!/usr/bin/env node
/**
 * design2flutter — HTML mockup -> Flutter widget transpiler (AST pipeline).
 *
 *   parse5 HTML AST -> normalised frame trees (parse.js)
 *   -> kit.css class rules -> widget specs (widgetMap.js)
 *   -> token-mapped Dart source (emit.js)
 *
 * Usage:
 *   node src/index.js --design ../docs/design --out output [--frames H07,H12,T21]
 *   node src/index.js --check output            # structural lint of generated Dart
 */
'use strict';
const fs = require('fs');
const path = require('path');
const { parseFile } = require('./parse');
const { emitScreen } = require('./emit');

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--design') args.design = argv[++i];
    else if (a === '--out') args.out = argv[++i];
    else if (a === '--frames') args.frames = argv[++i].split(',').map(s => s.trim());
    else if (a === '--check') args.check = argv[++i];
    else if (a === '--list') args.list = true;
    else args._.push(a);
  }
  return args;
}

function lintDart(src) {
  // structural checks without a Dart SDK: balance, no HTML leakage, no raw hex
  const problems = [];
  const pairs = { '(': ')', '[': ']', '{': '}' };
  const stack = [];
  // strip strings (with escape handling) and comments
  const noStrings = src.replace(/'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\/\/[^\n]*|\/\*[\s\S]*?\*\//g, '');
  for (const ch of noStrings) {
    if (pairs[ch]) stack.push(pairs[ch]);
    else if (Object.values(pairs).includes(ch)) {
      if (stack.pop() !== ch) { problems.push('unbalanced brackets'); break; }
    }
  }
  if (stack.length) problems.push(`${stack.length} unclosed brackets`);
  if (/<\/?(div|span|svg|use|html|body)\b/i.test(src)) problems.push('HTML leaked into Dart');
  if (/Color\(0x[0-9a-fA-F]+\)/.test(src)) problems.push('raw Color(0x..) literal (token rule)');
  if (/class \w+Screen extends/.test(src) === false) problems.push('missing screen class');
  return problems;
}

function main() {
  const args = parseArgs(process.argv);

  if (args.check) {
    const files = fs.readdirSync(args.check).filter(f => f.endsWith('.dart'));
    let bad = 0;
    for (const f of files) {
      const problems = lintDart(fs.readFileSync(path.join(args.check, f), 'utf8'));
      if (problems.length) { bad++; console.error(`FAIL ${f}: ${problems.join('; ')}`); }
      else console.log(`ok   ${f}`);
    }
    process.exit(bad ? 1 : 0);
  }

  const design = path.resolve(args.design || '../docs/design');
  const out = path.resolve(args.out || 'output');
  const htmlDir = path.join(design, 'html');
  const files = fs.readdirSync(htmlDir).filter(f => /^frames-.*\.html$/.test(f)).sort();
  fs.mkdirSync(out, { recursive: true });

  let generated = 0, skipped = 0;
  const manifest = [];
  for (const f of files) {
    const frames = parseFile(path.join(htmlDir, f));
    for (const fr of frames) {
      if (args.frames && !args.frames.some(pfx => fr.frame.startsWith(pfx))) continue;
      if (args.list) { manifest.push(`${fr.frame}  (${fr.theme}, ${fr.width}x${fr.height})`); continue; }
      fr.file = f;
      const dart = emitScreen(fr);
      const problems = lintDart(dart);
      if (problems.length) { skipped++; console.error(`SKIP ${fr.frame}: ${problems.join('; ')}`); continue; }
      const outFile = path.join(out, `${fr.frame.replace(/-/g, '_')}.dart`);
      fs.writeFileSync(outFile, dart);
      generated++;
      manifest.push(`${fr.frame} -> ${path.basename(outFile)}`);
    }
  }
  if (args.list) { console.log(manifest.join('\n')); return; }
  fs.writeFileSync(path.join(out, 'manifest.txt'), manifest.join('\n') + '\n');
  console.log(`design2flutter: ${generated} screens generated, ${skipped} skipped (lint) -> ${out}`);
}

main();
