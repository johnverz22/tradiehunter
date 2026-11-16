// v1.7 design tokens — mirrors html/kit.css. Use via Theme.of(context).extension<THColors>()!
import 'package:flutter/material.dart';

abstract class Space { static const s1=4.0,s2=8.0,s3=12.0,s4=16.0,s5=20.0,s6=24.0,s7=32.0,s8=40.0,gutter=20.0; }
abstract class Radii { static const card=20.0,control=14.0,tile=16.0,sheet=28.0,pill=999.0; }
abstract class Sizes { static const tapMin=48.0,button=56.0,buttonSecondary=52.0,input=56.0,nav=68.0,appBar=56.0,fab=56.0; }

@immutable
class THColors extends ThemeExtension<THColors> {
  final Color paper, surface, text, textSoft, textBrand, brand, onBrand, accent, accentText, line, tintBrand, track, danger, success;
  const THColors({required this.paper,required this.surface,required this.text,required this.textSoft,required this.textBrand,required this.brand,
    required this.onBrand,required this.accent,required this.accentText,required this.line,required this.tintBrand,required this.track,required this.danger,required this.success});
  static const light = THColors(paper:Color(0xFFF6F4EE),surface:Color(0xFFFFFFFF),text:Color(0xFF14181B),textSoft:Color(0xFF5B6570),textBrand:Color(0xFF193957),
    brand:Color(0xFF193957),onBrand:Color(0xFFFFFFFF),accent:Color(0xFFE38B29),accentText:Color(0xFF8F4F08),line:Color(0xFFE4E0D4),tintBrand:Color(0x1F3C75AA),track:Color(0x1F193957),
    danger:Color(0xFFB23A2E),success:Color(0xFF3A7D5C));
  static const dark = THColors(paper:Color(0xFF14181B),surface:Color(0xFF1E2328),text:Color(0xFFECEAE3),textSoft:Color(0xFF9AA4AC),textBrand:Color(0xFF89AFD2),
    brand:Color(0xFF89AFD2),onBrand:Color(0xFF193957),accent:Color(0xFFE38B29),accentText:Color(0xFFE38B29),line:Color(0x1FFFFFFF),tintBrand:Color(0x333C75AA),track:Color(0x24FFFFFF),
    danger:Color(0xFFE8968E),success:Color(0xFF8FC9A8));
  // Outdoor = light + flat: drop shadows/blur, add 1px line borders, textSoft 0xFF46505A.
  static const outdoor = THColors(paper:Color(0xFFF6F4EE),surface:Color(0xFFFFFFFF),text:Color(0xFF14181B),textSoft:Color(0xFF46505A),textBrand:Color(0xFF193957),
    brand:Color(0xFF193957),onBrand:Color(0xFFFFFFFF),accent:Color(0xFFE38B29),accentText:Color(0xFF8F4F08),line:Color(0x47193957),tintBrand:Color(0x1F3C75AA),track:Color(0x1F193957),
    danger:Color(0xFFB23A2E),success:Color(0xFF3A7D5C));
  @override THColors copyWith() => this;
  @override THColors lerp(ThemeExtension<THColors>? o, double t) => this;
}
