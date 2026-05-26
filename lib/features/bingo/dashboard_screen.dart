import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/box_slot.dart';
import '../../data/models/game_model.dart';
import '../../data/models/question_model.dart';
import '../../data/repositories/game_repository.dart';
import '../../data/repositories/question_repository.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/animated_entry.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/app_skeleton.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../auth/auth_providers.dart';
import 'bingo_providers.dart';
import 'widgets/bingo_slot_tile.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final game = ref.watch(activeGameProvider);
    final questions = ref.watch(questionsProvider);

    // One-shot celebration: fire only on the upward transition into "all
    // slots filled" — re-renders for other reasons don't re-trigger.
    ref.listen<int>(completedSlotCountProvider, (prev, curr) {
      final total = questions.valueOrNull?.length ?? 0;
      if (total <= 0) return;
      if (prev != null && prev < total && curr >= total) {
        _showCelebration(context);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: GestureDetector(
            onTap: () => context.push('/profile'),
            child: ProfileAvatar(
              name: user?.name,
              size: 36,
              borderWidth: 1.5,
            ),
          ),
        ),
        title: const Text('Namma Bingo'),
        actions: [
          IconButton(
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Profile & settings',
          ),
        ],
      ),
      body: switch ((game, questions)) {
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) =>
          AppErrorState(message: error.toString()),
        (AsyncLoading(), _) || (_, AsyncLoading()) => const _SkeletonBody(),
        (AsyncData(value: null), _) => const AppEmptyState(
            icon: Icons.event_busy_outlined,
            title: 'No active game',
            message: "We couldn't find an active bingo game. "
                'Check back once the organizer starts the event.',
          ),
        (AsyncData(:final value), AsyncData(value: final qs))
            when value != null =>
          _Body(game: value!, questions: qs),
        _ => const _SkeletonBody(),
      },
    );
  }

  void _showCelebration(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.accentGradient,
                ),
                child: const Icon(Icons.celebration_rounded,
                    size: 56, color: AppColors.background),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Bingo!',
                  style: AppTypography.display.copyWith(letterSpacing: 1)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'You filled every slot. Great networking.',
                style: AppTypography.bodyMuted,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Awesome',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.game,
    required this.questions,
  });

  final GameModel game;
  final List<QuestionModel> questions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = ref.watch(completedSlotCountProvider);
    final total = questions.length;
    final remaining = (total - completed).clamp(0, total);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _ProgressCard(
              completed: completed,
              total: total,
              remaining: remaining,
            ),
          ),
          Expanded(
            child: questions.isEmpty
                ? const AppEmptyState(
                    icon: Icons.list_alt_outlined,
                    title: 'No questions yet',
                    message:
                        "The organizer hasn't added prompts for this game yet.",
                  )
                : Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: _SlotGrid(questions: questions),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppButton(
              label: completed >= total && total > 0
                  ? 'Board complete!'
                  : 'Scan to connect',
              icon: Icons.qr_code_scanner,
              onPressed: (questions.isEmpty || completed >= total)
                  ? null
                  : () => _showQuestionPicker(context, questions),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuestionPicker(
      BuildContext context, List<QuestionModel> questions) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _QuestionPickerSheet(questions: questions),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.completed,
    required this.total,
    required this.remaining,
  });

  final int completed;
  final int total;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;
    final isDone = remaining == 0 && total > 0;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDone ? 'Bingo! Complete.' : '$remaining more to bingo',
                      style: AppTypography.subtitle
                          .copyWith(color: AppColors.accent),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDone
                          ? 'Tap any tile to revisit a connection.'
                          : 'Scan QRs to fill your board.',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.accent.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Text(
                  '$completed / $total',
                  style: AppTypography.title.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _AnimatedProgressBar(progress: progress),
        ],
      ),
    );
  }
}

/// Gradient progress bar with a soft accent glow that tweens to the target
/// value whenever [progress] changes. Milestone dots at 25/50/75 mark
/// quarters and gently flip to accent as they're passed.
class _AnimatedProgressBar extends StatelessWidget {
  const _AnimatedProgressBar({required this.progress});

  /// 0..1
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return LayoutBuilder(
            builder: (context, c) {
              final fillWidth = c.maxWidth * value;
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Track.
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  // Filled gradient + glow.
                  Container(
                    width: fillWidth,
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                  // Milestone dots at 25/50/75.
                  for (final m in const [0.25, 0.5, 0.75])
                    Positioned(
                      left: c.maxWidth * m - 3,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: value >= m
                              ? AppColors.background
                              : AppColors.textTertiary,
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SlotGrid extends ConsumerWidget {
  const _SlotGrid({required this.questions});

  final List<QuestionModel> questions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(mySessionProvider).valueOrNull;
    final slots = session?.slots ?? const <String, BoxSlot>{};

    final crossAxisCount = _crossAxisCount(MediaQuery.sizeOf(context).width);

    return GridView.builder(
      itemCount: questions.length,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final question = questions[index];
        final slotNumber = index + 1;
        final slot = slots[slotNumber.toString()];
        return AnimatedEntry(
          // Keyed on question id so reordering doesn't replay the entrance.
          key: ValueKey('entry-${question.id}'),
          index: index,
          stagger: const Duration(milliseconds: 35),
          child: BingoSlotTile(
            key: ValueKey(question.id),
            slotNumber: slotNumber,
            slot: slot,
            onTap: () => _onTileTap(context, slotNumber, slot, question),
          ),
        );
      },
    );
  }

  int _crossAxisCount(double width) {
    if (width > 900) return 6;
    if (width > 600) return 5;
    if (width > 380) return 4;
    return 3;
  }

  void _onTileTap(BuildContext context, int slotNumber, BoxSlot? slot,
      QuestionModel question) {
    if (slot == null) {
      context.push('/scan', extra: {
        'slotIndex': slotNumber,
        'questionId': question.id,
        'questionText': question.text,
      });
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        builder: (_) => _SlotDetailsSheet(slot: slot, question: question),
      );
    }
  }
}

class _QuestionPickerSheet extends ConsumerWidget {
  const _QuestionPickerSheet({required this.questions});

  final List<QuestionModel> questions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(mySessionProvider).valueOrNull;
    final filled = session?.slots ?? const <String, BoxSlot>{};
    final open = <(int, QuestionModel)>[];
    for (var i = 0; i < questions.length; i++) {
      final slotNumber = i + 1;
      if (!filled.containsKey(slotNumber.toString())) {
        open.add((slotNumber, questions[i]));
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle pill — standard "this sheet can be dismissed"
            // affordance.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text('Pick a prompt to scan for',
                      style: AppTypography.subtitle),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.textSecondary,
                  tooltip: 'Close',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: open.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, i) {
                  final (slotNumber, question) = open[i];
                  return AppCard(
                    color: AppColors.surfaceElevated,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/scan', extra: {
                        'slotIndex': slotNumber,
                        'questionId': question.id,
                        'questionText': question.text,
                      });
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.accentMuted,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$slotNumber',
                              style: AppTypography.label
                                  .copyWith(color: AppColors.accent)),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(question.text,
                              style: AppTypography.body),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppColors.textTertiary),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotDetailsSheet extends StatelessWidget {
  const _SlotDetailsSheet({required this.slot, required this.question});

  final BoxSlot slot;
  final QuestionModel question;

  Future<void> _openLinkedIn(BuildContext context) async {
    final url = slot.scannedLinkedinUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open LinkedIn')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLinkedIn =
        slot.scannedLinkedinUrl != null && slot.scannedLinkedinUrl!.isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ProfileAvatar(
                  name: slot.scannedName,
                  size: 56,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(slot.scannedName, style: AppTypography.title),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentMuted,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Slot ${slot.slotIndex}',
                            style: AppTypography.label
                                .copyWith(color: AppColors.accent)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              color: AppColors.surfaceElevated,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Prompt',
                      style: AppTypography.label
                          .copyWith(color: AppColors.accent)),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(slot.questionText, style: AppTypography.body),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: hasLinkedIn
                  ? 'Open LinkedIn profile'
                  : 'No LinkedIn shared',
              icon: Icons.link,
              onPressed: hasLinkedIn ? () => _openLinkedIn(context) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBody extends StatelessWidget {
  const _SkeletonBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSkeleton(height: 80),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: GridView.builder(
              itemCount: 15,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1,
              ),
              itemBuilder: (_, __) => const AppSkeleton(height: 80),
            ),
          ),
        ],
      ),
    );
  }
}
