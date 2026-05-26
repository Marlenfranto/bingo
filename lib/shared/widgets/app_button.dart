import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum AppButtonVariant { primary, secondary, tertiary }

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expanded;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.loading;

    final inner = widget.loading
        ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.background,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 20),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final button = switch (widget.variant) {
      AppButtonVariant.primary => ElevatedButton(
          onPressed: disabled ? null : widget.onPressed,
          child: inner,
        ),
      AppButtonVariant.secondary => OutlinedButton(
          onPressed: disabled ? null : widget.onPressed,
          child: inner,
        ),
      AppButtonVariant.tertiary => TextButton(
          onPressed: disabled ? null : widget.onPressed,
          child: inner,
        ),
    };

    return Listener(
      // Listener is purely passive — it observes pointer events without
      // claiming the gesture, so the underlying Material button still owns
      // the tap and handles ripple/onPressed.
      behavior: HitTestBehavior.translucent,
      onPointerDown: disabled
          ? null
          : (_) {
              HapticFeedback.lightImpact();
              setState(() => _pressed = true);
            },
      onPointerUp: (_) {
        if (_pressed) setState(() => _pressed = false);
      },
      onPointerCancel: (_) {
        if (_pressed) setState(() => _pressed = false);
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          width: widget.expanded ? double.infinity : null,
          height: 52,
          child: button,
        ),
      ),
    );
  }
}
