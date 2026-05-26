import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/box_slot.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../bingo/bingo_providers.dart';

/// Connections = the list of people you've scanned, ordered most recent first.
/// Sourced from your session's slots — no extra query.
class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(mySessionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Connections')),
      body: session.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(
          child: Text(e.toString(), style: AppTypography.bodyMuted),
        ),
        data: (s) {
          final slots = (s?.slots.values.toList() ?? <BoxSlot>[])
            ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
          if (slots.isEmpty) {
            return const AppEmptyState(
              icon: Icons.people_outline,
              title: 'No connections yet',
              message: 'Scan someone to add them to your network.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: slots.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _ConnectionTile(slot: slots[i]),
          );
        },
      ),
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({required this.slot});

  final BoxSlot slot;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          ProfileAvatar(
            name: slot.scannedName,
            size: 48,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slot.scannedName, style: AppTypography.subtitle),
                const SizedBox(height: 2),
                Text(
                  slot.questionText,
                  style: AppTypography.bodyMuted,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#${slot.slotIndex}',
              style: AppTypography.label.copyWith(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}
