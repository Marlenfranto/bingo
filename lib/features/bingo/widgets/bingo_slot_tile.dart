import 'package:flutter/material.dart';

import '../../../data/models/box_slot.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/profile_avatar.dart';

/// One tile in the bingo grid. Stateful so we can play a quick scale-pop
/// when the slot transitions from empty to filled (scan confirmation cue).
class BingoSlotTile extends StatefulWidget {
  const BingoSlotTile({
    super.key,
    required this.slotNumber,
    required this.slot,
    required this.onTap,
  });

  /// 1-based slot index for display.
  final int slotNumber;

  /// Null when this slot is empty.
  final BoxSlot? slot;

  final VoidCallback onTap;

  @override
  State<BingoSlotTile> createState() => _BingoSlotTileState();
}

class _BingoSlotTileState extends State<BingoSlotTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;
  late final Animation<double> _scale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 55,
      ),
    ]).animate(_pop);
  }

  @override
  void didUpdateWidget(BingoSlotTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slot == null && widget.slot != null) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  bool get _filled => widget.slot != null;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _filled
          ? 'Slot ${widget.slotNumber} — ${widget.slot!.scannedName}'
          : 'Empty slot ${widget.slotNumber}',
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: AppRadius.all,
            boxShadow: _filled
                ? [
                    BoxShadow(
                      color: AppColors.accent
                          .withOpacity(_pressed ? 0.45 : 0.28),
                      blurRadius: _pressed ? 22 : 16,
                      spreadRadius: _pressed ? 1 : 0,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(_pressed ? 0.32 : 0.18),
                      blurRadius: _pressed ? 12 : 6,
                      offset: Offset(0, _pressed ? 4 : 2),
                    ),
                  ],
          ),
          child: ClipRRect(
            // Clip everything to the rounded tile shape so corner badges
            // can't bleed past the radius. Was a real source of overflow.
            borderRadius: AppRadius.all,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onHighlightChanged: (v) => setState(() => _pressed = v),
                splashColor: AppColors.accent.withOpacity(0.18),
                highlightColor: AppColors.accent.withOpacity(0.08),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.9, end: 1.0).animate(anim),
                      child: child,
                    ),
                  ),
                  // StackFit.expand forces each child (filled / empty) to
                  // fill the tile bounds. Without this, the inner Column
                  // would stretch vertically while staying narrow, which is
                  // what was making empty tiles look like vertical pills.
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.center,
                    fit: StackFit.expand,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  ),
                  child: _filled
                      ? _FilledTile(
                          key: const ValueKey('filled'),
                          slot: widget.slot!,
                        )
                      : _EmptyTile(
                          key: const ValueKey('empty'),
                          slotNumber: widget.slotNumber,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Completed slot: gradient background, avatar + name, small checkmark dot.
///
/// No slot-number badge — the grid position already tells you the slot, and
/// fitting one inside a ~70px mobile cell kept clipping the avatar.
class _FilledTile extends StatelessWidget {
  const _FilledTile({super.key, required this.slot});

  final BoxSlot slot;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00FF88), Color(0xFF00B85C)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Stack(
          children: [
            // Centered content. FittedBox lets the avatar+name shrink rather
            // than overflow on narrow cells.
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ProfileAvatar(name: slot.scannedName, size: 36),
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 84),
                      child: Text(
                        slot.scannedName,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.background,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Small checkmark pill in the top-right.
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.85),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 11,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty slot: surfaceDim fill, soft accent border, slot number + scanner
/// icon. The border is a plain 1px line rather than a custom-painted dashed
/// stroke — the dashed version was painting at the wrong bounds on small
/// cells (looked like a stadium around the content).
class _EmptyTile extends StatelessWidget {
  const _EmptyTile({super.key, required this.slotNumber});

  final int slotNumber;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        border: Border.all(
          color: AppColors.accent.withOpacity(0.28),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$slotNumber',
                style: AppTypography.title.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.accentMuted,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 12,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
