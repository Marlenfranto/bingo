import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Circular initial-letter avatar. We removed network photo support — see
/// the SCHEMA notes on why Storage was dropped — but kept this widget so
/// every avatar in the app has consistent sizing / colors / typography.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.name,
    this.size = 40,
    this.borderColor = AppColors.accent,
    this.borderWidth = 1,
    this.backgroundColor,
    this.textColor,
  });

  final String? name;
  final double size;
  final Color borderColor;
  final double borderWidth;

  /// Override the avatar's fill. Defaults to [AppColors.surfaceElevated].
  /// Useful on accent-colored backgrounds (e.g. the gold podium tile) where
  /// the dark default disappears into a "hole".
  final Color? backgroundColor;

  /// Override the initial-letter color. Defaults to [AppColors.accent].
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final initial =
        (name != null && name!.isNotEmpty) ? name![0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? AppColors.surfaceElevated,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Center(
        child: Text(
          initial,
          style: AppTypography.title.copyWith(
            color: textColor ?? AppColors.accent,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
