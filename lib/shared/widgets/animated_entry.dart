import 'package:flutter/material.dart';

/// Fades + slides a child in once on first mount. Wrap list/grid items with
/// this and pass [index] to cascade their entrance (40 ms apart by default).
///
/// The stagger is capped via [maxStaggerIndex] so the 50th item doesn't take
/// a noticeable two seconds to appear.
class AnimatedEntry extends StatefulWidget {
  const AnimatedEntry({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 360),
    this.stagger = const Duration(milliseconds: 40),
    this.maxStaggerIndex = 20,
    this.offset = const Offset(0, 0.15),
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final int index;
  final Duration duration;
  final Duration stagger;
  final int maxStaggerIndex;

  /// Fraction of own size to slide from. (0, 0.15) means starting 15% below
  /// the resting position. Use Offset.zero to disable slide and fade only.
  final Offset offset;
  final Curve curve;

  @override
  State<AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _c, curve: widget.curve);
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(curved);

    final idx = widget.index.clamp(0, widget.maxStaggerIndex);
    final delay = widget.stagger * idx;
    if (delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
