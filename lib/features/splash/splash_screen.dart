import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/app_button.dart';
import '../auth/auth_providers.dart';

/// Shown while we (a) resolve cached Firebase auth or (b) sign in
/// anonymously for the first time. Errors render an inline retry instead
/// of a dead-end.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(authBootstrapProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/bingo.png', height: 96),
              const SizedBox(height: AppSpacing.lg),
              Text('Namma Bingo',
                  style: AppTypography.headline,
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xs),
              Text('Connect with people, fill your board',
                  style: AppTypography.bodyMuted,
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xxl),
              bootstrap.when(
                data: (_) =>
                    const CircularProgressIndicator(color: AppColors.accent),
                loading: () =>
                    const CircularProgressIndicator(color: AppColors.accent),
                error: (err, _) => _ErrorBlock(
                  message: err.toString(),
                  onRetry: () =>
                      ref.read(authBootstrapProvider.notifier).retry(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.cloud_off, size: 48, color: AppColors.error),
        const SizedBox(height: AppSpacing.md),
        Text("Couldn't connect", style: AppTypography.subtitle),
        const SizedBox(height: AppSpacing.xs),
        Text(message,
            style: AppTypography.bodyMuted, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Retry',
          icon: Icons.refresh,
          onPressed: onRetry,
          expanded: false,
        ),
      ],
    );
  }
}
