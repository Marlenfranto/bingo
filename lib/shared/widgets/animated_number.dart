import 'package:flutter/material.dart';

/// Smoothly tweens an integer counter when its [value] changes. Use on
/// kiosk-facing surfaces where a count jumping from 5 → 6 feels lifeless
/// next to the rest of the live animations.
///
/// Renders only the number — wrap or compose externally for suffixes (e.g.,
/// `Row([AnimatedNumber(value: count), Text(' / $total')])`).
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutCubic,
    this.textAlign,
  });

  final int value;
  final TextStyle style;
  final Duration duration;
  final Curve curve;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: value.toDouble(), end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (_, v, __) => Text(
        v.round().toString(),
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}
