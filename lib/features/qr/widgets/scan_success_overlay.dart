import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/confetti_burst.dart';
import '../../../shared/widgets/profile_avatar.dart';

/// Shows a full-screen celebration after a successful scan. Returns when the
/// user taps Continue, or after [autoDismiss] elapses — whichever first.
///
/// Uses [showGeneralDialog] so we get a real route (Android back button +
/// `Navigator.pop` work naturally) plus a custom barrier we can blur.
Future<void> showScanSuccessOverlay(
  BuildContext context, {
  required String scannedName,
  required int slotIndex,
  required String questionText,
  Duration autoDismiss = const Duration(seconds: 3),
}) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Scan success',
    // Custom blur+dark barrier is painted inside the page itself so it can
    // fade in alongside the card; here we keep the route barrier minimal.
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (_, __, ___) => _ScanSuccessPage(
      scannedName: scannedName,
      slotIndex: slotIndex,
      questionText: questionText,
      autoDismiss: autoDismiss,
    ),
    transitionBuilder: (_, animation, __, child) {
      // Whole-page fade in. Internal pieces have their own choreography.
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

class _ScanSuccessPage extends StatefulWidget {
  const _ScanSuccessPage({
    required this.scannedName,
    required this.slotIndex,
    required this.questionText,
    required this.autoDismiss,
  });

  final String scannedName;
  final int slotIndex;
  final String questionText;
  final Duration autoDismiss;

  @override
  State<_ScanSuccessPage> createState() => _ScanSuccessPageState();
}

class _ScanSuccessPageState extends State<_ScanSuccessPage>
    with TickerProviderStateMixin {
  // Single controller drives the entrance choreography — scale, glow,
  // checkmark draw, text fade. Sub-animations slice this with Intervals.
  late final AnimationController _entrance;

  // Separate looping controller for the gentle post-entrance halo pulse.
  late final AnimationController _halo;

  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _halo = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _dismissTimer = Timer(widget.autoDismiss, () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _entrance.dispose();
    _halo.dispose();
    super.dispose();
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    // Sub-curves carved out of the master entrance:
    //   0.00–0.55  card scale + backdrop blur
    //   0.10–0.85  checkmark stroke draws
    //   0.30–1.00  identity (avatar, name, slot, question) fade-in
    final cardCurve = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
    );
    final checkCurve = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.10, 0.85, curve: Curves.easeOutCubic),
    );
    final identityCurve = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.30, 1.0, curve: Curves.easeOut),
    );

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        // Tap anywhere outside the card to dismiss.
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        child: Stack(
          children: [
            // Blurred backdrop.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: cardCurve,
                builder: (_, __) {
                  final t = cardCurve.value.clamp(0.0, 1.0);
                  return BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12 * t, sigmaY: 12 * t),
                    child: Container(
                      color: Colors.black.withOpacity(0.55 * t),
                    ),
                  );
                },
              ),
            ),
            // Confetti emits from the top of the screen, drifts down.
            const Positioned.fill(
              child: ConfettiBurst(
                particleCount: 36,
                duration: Duration(milliseconds: 2600),
              ),
            ),
            // Centered card.
            Center(
              child: GestureDetector(
                // Don't let taps on the card bubble to the dismiss handler.
                onTap: () {},
                child: AnimatedBuilder(
                  animation: cardCurve,
                  builder: (_, child) {
                    final t = cardCurve.value.clamp(0.0, 1.0);
                    return Opacity(
                      opacity: t,
                      child: Transform.scale(
                        scale: 0.85 + 0.15 * t,
                        child: child,
                      ),
                    );
                  },
                  child: _Card(
                    scannedName: widget.scannedName,
                    slotIndex: widget.slotIndex,
                    questionText: widget.questionText,
                    checkProgress: checkCurve,
                    identityCurve: identityCurve,
                    halo: _halo,
                    onContinue: _dismiss,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.scannedName,
    required this.slotIndex,
    required this.questionText,
    required this.checkProgress,
    required this.identityCurve,
    required this.halo,
    required this.onContinue,
  });

  final String scannedName;
  final int slotIndex;
  final String questionText;
  final Animation<double> checkProgress;
  final Animation<double> identityCurve;
  final Animation<double> halo;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.lg),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xxl,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
          border: Border.all(
            color: AppColors.accent.withOpacity(0.45),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.35),
              blurRadius: 36,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SuccessCheckmark(progress: checkProgress, halo: halo),
            const SizedBox(height: AppSpacing.lg),
            _FadeInSlide(
              animation: identityCurve,
              startOffset: const Offset(0, 0.4),
              child: Text(
                'Connection added!',
                style: AppTypography.headline.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _FadeInSlide(
              animation: identityCurve,
              startOffset: const Offset(0, 0.5),
              child: _SlotBadge(slotIndex: slotIndex),
            ),
            const SizedBox(height: AppSpacing.lg),
            _FadeInSlide(
              animation: identityCurve,
              startOffset: const Offset(0, 0.6),
              child: Column(
                children: [
                  ProfileAvatar(
                    name: scannedName,
                    size: 64,
                    borderWidth: 2,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    scannedName,
                    style: AppTypography.title.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _FadeInSlide(
              animation: identityCurve,
              startOffset: const Offset(0, 0.7),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: AppRadius.input,
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prompt',
                      style: AppTypography.label
                          .copyWith(color: AppColors.accent),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      questionText,
                      style: AppTypography.body,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _FadeInSlide(
              animation: identityCurve,
              startOffset: const Offset(0, 0.8),
              child: AppButton(
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                onPressed: onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big animated checkmark inside a gradient accent disc with a pulsing halo.
class _SuccessCheckmark extends StatelessWidget {
  const _SuccessCheckmark({required this.progress, required this.halo});

  final Animation<double> progress;
  final Animation<double> halo;

  static const _size = 88.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([progress, halo]),
      builder: (_, __) {
        final p = progress.value.clamp(0.0, 1.0);
        final h = halo.value;
        return SizedBox(
          width: _size + 28,
          height: _size + 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulsing halo (continuous).
              Container(
                width: _size + 28 + (h * 10),
                height: _size + 28 + (h * 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withOpacity(0.08 + h * 0.08),
                ),
              ),
              // Inner gradient disc + glow.
              Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.accentGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.55),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              // Stroke-drawn checkmark.
              SizedBox(
                width: _size,
                height: _size,
                child: CustomPaint(
                  painter: _CheckmarkPainter(progress: p),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Stroked checkmark drawn progressively from 0..1. Path is the classic
/// two-segment tick scaled to the canvas size.
class _CheckmarkPainter extends CustomPainter {
  _CheckmarkPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final w = size.width;
    final h = size.height;
    // Tick coordinates as fractions of the disc.
    final p1 = Offset(w * 0.27, h * 0.52);
    final p2 = Offset(w * 0.45, h * 0.70);
    final p3 = Offset(w * 0.74, h * 0.36);

    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy);

    final metric = path.computeMetrics().first;
    final extract = metric.extractPath(0, metric.length * progress);

    final paint = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(extract, paint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter old) => old.progress != progress;
}

/// Slot # pill — small, sits below the headline.
class _SlotBadge extends StatelessWidget {
  const _SlotBadge({required this.slotIndex});

  final int slotIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accent.withOpacity(0.5)),
      ),
      child: Text(
        'Slot $slotIndex locked in',
        style: AppTypography.label.copyWith(
          color: AppColors.accent,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Tiny helper: fade + small slide driven by an Animation<double>. Used to
/// cascade the card's content in once the card itself has scaled into view.
class _FadeInSlide extends StatelessWidget {
  const _FadeInSlide({
    required this.animation,
    required this.startOffset,
    required this.child,
  });

  final Animation<double> animation;
  final Offset startOffset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, c) {
        final t = animation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(
              startOffset.dx * (1 - t) * 40,
              startOffset.dy * (1 - t) * 40,
            ),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}
