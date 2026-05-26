import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';

/// Wraps the dashboard / connections / qr-code tabs with a bottom nav.
/// Driven by `go_router` ShellRoute — the child swaps without rebuilding
/// the shell itself.
class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key, required this.child});

  final Widget child;

  static const _routes = ['/', '/connections', '/qr-code'];

  int _indexFor(String location) {
    if (location.startsWith('/connections')) return 1;
    if (location.startsWith('/qr-code')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _indexFor(location);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.button,
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavItem(
                icon: Icons.grid_view_rounded,
                label: 'Board',
                selected: index == 0,
                onTap: () => context.go('/'),
              ),
              _NavItem(
                icon: Icons.people_outline_rounded,
                label: 'Network',
                selected: index == 1,
                onTap: () => context.go('/connections'),
              ),
              _NavItem(
                icon: Icons.qr_code_rounded,
                label: 'My QR',
                selected: index == 2,
                onTap: () => context.go('/qr-code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.button,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: AppRadius.button,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppColors.background : AppColors.textTertiary,
              ),
              if (selected) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: AppTypography.label.copyWith(
                    color: AppColors.background,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
