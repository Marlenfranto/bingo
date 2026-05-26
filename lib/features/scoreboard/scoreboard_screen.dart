import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/session_model.dart';
import '../../data/repositories/game_repository.dart';
import '../../data/repositories/question_repository.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/animated_entry.dart';
import '../../shared/widgets/animated_number.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/confetti_burst.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../auth/auth_providers.dart';
import 'scoreboard_providers.dart';

/// Live scoreboard for projector / fullscreen kiosk display.
///
/// Designed to be opened at `/scoreboard` on a separate browser, then
/// fullscreened (F11). Does not require profile onboarding — only auth.
/// Rebuilds in real time as scans come in via Firestore streams.
class ScoreboardScreen extends ConsumerWidget {
  const ScoreboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The scoreboard bypasses the router auth gate so it can be opened
    // directly on a kiosk URL. That means we have to handle the "auth still
    // resolving" case here ourselves — show a holding screen until the
    // anonymous sign-in fires and Firestore reads become possible.
    final auth = ref.watch(authStateProvider);
    if (auth.isLoading || auth.valueOrNull == null) {
      return const _AuthHoldingScreen();
    }

    final game = ref.watch(activeGameProvider).valueOrNull;
    final questions = ref.watch(questionsProvider).valueOrNull;
    final ranked = ref.watch(scoreboardProvider);
    final winner = ref.watch(winnerProvider);
    final players = ref.watch(playerCountProvider);
    final total = questions?.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _AmbientBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    title: game?.title ?? 'Namma Bingo',
                    players: players,
                    total: total,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: winner == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppSpacing.xl),
                            child: _WinnerBanner(
                              key: ValueKey('winner-${winner.uid}'),
                              winner: winner,
                              total: total,
                            ),
                          ),
                  ),
                  Expanded(
                    child: ranked.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.hourglass_empty,
                            title: 'Waiting for the first scan…',
                            message:
                                'The board updates here in real time as players scan each other.',
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _Podium(
                                  top: ranked.take(3).toList(),
                                  total: total,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xl),
                              Expanded(
                                flex: 4,
                                child: _LeaderboardList(
                                  entries: ranked.skip(3).take(7).toList(),
                                  total: total,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.players,
    required this.total,
  });

  final String title;
  final int players;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: AppRadius.button,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _PulsingDot(),
              const SizedBox(width: AppSpacing.xs),
              Text('LIVE',
                  style: AppTypography.label.copyWith(
                    color: AppColors.background,
                    fontSize: 14,
                  )),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            title,
            style: AppTypography.display
                .copyWith(fontSize: 48, letterSpacing: 0),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AnimatedNumber(
              value: players,
              style: AppTypography.title.copyWith(
                color: AppColors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              ' ${players == 1 ? "player" : "players"}  ·  $total prompts',
              style: AppTypography.title
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.background.withOpacity(0.4 + _c.value * 0.6),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Winner banner — animated entrance + one-shot confetti burst
// ---------------------------------------------------------------------------

class _WinnerBanner extends StatefulWidget {
  const _WinnerBanner({super.key, required this.winner, required this.total});

  final SessionModel winner;
  final int total;

  @override
  State<_WinnerBanner> createState() => _WinnerBannerState();
}

class _WinnerBannerState extends State<_WinnerBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _entrance,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (_, __) {
        final t = curve.value.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, -16 * (1 - t)),
          child: Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.96 + 0.04 * t,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _WinnerBannerBody(
                    winner: widget.winner,
                    total: widget.total,
                    glow: t,
                  ),
                  const Positioned.fill(child: ConfettiBurst()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WinnerBannerBody extends StatelessWidget {
  const _WinnerBannerBody({
    required this.winner,
    required this.total,
    required this.glow,
  });

  final SessionModel winner;
  final int total;

  /// 0..1 — drives the soft accent glow during the entrance animation.
  final double glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: AppRadius.card,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.35 + 0.25 * glow),
            blurRadius: 28 + 16 * glow,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded,
              size: 56, color: AppColors.background),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BINGO! ${_displayName(winner)} got there first.',
                  style: AppTypography.title.copyWith(
                    color: AppColors.background,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Filled all $total prompts',
                  style: AppTypography.body.copyWith(
                    color: AppColors.background.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Podium
// ---------------------------------------------------------------------------

class _Podium extends StatelessWidget {
  const _Podium({required this.top, required this.total});

  final List<SessionModel> top;
  final int total;

  @override
  Widget build(BuildContext context) {
    final first = top.isNotEmpty ? top[0] : null;
    final second = top.length > 1 ? top[1] : null;
    final third = top.length > 2 ? top[2] : null;

    // Stagger order matches visual hierarchy: #2 first (left), then #1
    // (center, the punchline), then #3 (right).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: AnimatedEntry(
            index: 0,
            stagger: const Duration(milliseconds: 120),
            offset: const Offset(0, 0.25),
            child: _PodiumTile(
              rank: 2,
              session: second,
              total: total,
              heightFactor: 0.65,
              medalColor: const Color(0xFFC0C7D6), // silver
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AnimatedEntry(
            index: 1,
            stagger: const Duration(milliseconds: 120),
            offset: const Offset(0, 0.3),
            child: _PodiumTile(
              rank: 1,
              session: first,
              total: total,
              heightFactor: 1.0,
              highlight: true,
              medalColor: const Color(0xFFFFD700), // gold
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AnimatedEntry(
            index: 2,
            stagger: const Duration(milliseconds: 120),
            offset: const Offset(0, 0.2),
            child: _PodiumTile(
              rank: 3,
              session: third,
              total: total,
              heightFactor: 0.5,
              medalColor: const Color(0xFFCD7F32), // bronze
            ),
          ),
        ),
      ],
    );
  }
}

class _PodiumTile extends StatelessWidget {
  const _PodiumTile({
    required this.rank,
    required this.session,
    required this.total,
    required this.heightFactor,
    required this.medalColor,
    this.highlight = false,
  });

  final int rank;
  final SessionModel? session;
  final int total;
  final double heightFactor;
  final bool highlight;
  final Color medalColor;

  @override
  Widget build(BuildContext context) {
    final empty = session == null;
    final name = empty ? '—' : _displayName(session!);
    final count = empty ? 0 : session!.completedCount;

    return LayoutBuilder(
      builder: (context, c) {
        final height = c.maxHeight * heightFactor;
        return Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            height: height,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadius.card,
              gradient: highlight
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.accent, AppColors.accentDark],
                    )
                  : null,
              color: highlight ? null : AppColors.surfaceElevated,
              border: Border.all(
                color:
                    highlight ? Colors.transparent : AppColors.divider,
                width: 1,
              ),
              boxShadow: highlight
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.35),
                        blurRadius: 26,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Medal(
                  rank: rank,
                  color: medalColor,
                  large: highlight,
                ),
                const SizedBox(height: AppSpacing.md),
                if (!empty)
                  ProfileAvatar(
                    name: session!.scannerName.isNotEmpty
                        ? session!.scannerName
                        : 'Player',
                    size: highlight ? 72 : 56,
                    // On the gold gradient, the dark default avatar reads as
                    // a hole. Flip it: white circle, dark accent text.
                    backgroundColor: highlight ? Colors.white : null,
                    textColor: highlight ? AppColors.accentDark : null,
                    borderColor: highlight
                        ? Colors.white.withOpacity(0.9)
                        : AppColors.accent,
                    borderWidth: highlight ? 2 : 1,
                  )
                else
                  _EmptyAvatarPlaceholder(
                    size: highlight ? 72 : 56,
                    onAccent: highlight,
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  empty ? 'Open' : name,
                  style: AppTypography.headline.copyWith(
                    color: highlight
                        ? AppColors.background
                        : (empty
                            ? AppColors.textTertiary
                            : AppColors.textPrimary),
                    fontSize: highlight ? 30 : 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: empty ? 1.2 : 0,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                if (empty)
                  Text(
                    'Waiting…',
                    style: AppTypography.bodyMuted.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 14,
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      AnimatedNumber(
                        value: count,
                        style: AppTypography.display.copyWith(
                          color: highlight
                              ? AppColors.background
                              : AppColors.accent,
                          fontSize: highlight ? 48 : 36,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        ' / $total',
                        style: AppTypography.title.copyWith(
                          color: (highlight
                                  ? AppColors.background
                                  : AppColors.textSecondary)
                              .withOpacity(0.75),
                          fontSize: highlight ? 24 : 20,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Gold/silver/bronze trophy badge above the avatar on each podium tile.
/// Stylized as a real trophy icon (Icons.emoji_events) on a tinted disc with
/// a soft outer glow — reads as a medal from across the room.
class _Medal extends StatelessWidget {
  const _Medal({
    required this.rank,
    required this.color,
    required this.large,
  });

  final int rank;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 56.0 : 44.0;
    final iconSize = large ? 32.0 : 24.0;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(color, Colors.white, 0.35)!,
                color,
                Color.lerp(color, Colors.black, 0.25)!,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            border: Border.all(
              color: Color.lerp(color, Colors.white, 0.5)!,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.65),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.emoji_events_rounded,
              size: iconSize,
              color: Colors.black.withOpacity(0.7),
            ),
          ),
        ),
        // Small numeric rank tag in the corner — keeps the rank legible even
        // if all three trophy tints read similarly from a distance.
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: large ? 22 : 18,
            height: large ? 22 : 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.background,
              border: Border.all(color: color, width: 1.5),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: large ? 11 : 10,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Placeholder shown on empty podium tiles. A dashed circle with a person
/// silhouette reads as "this seat is reserved" instead of as a hole.
class _EmptyAvatarPlaceholder extends StatelessWidget {
  const _EmptyAvatarPlaceholder({
    required this.size,
    required this.onAccent,
  });

  final double size;
  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    final fg = onAccent
        ? AppColors.background.withOpacity(0.35)
        : AppColors.textTertiary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onAccent
            ? Colors.white.withOpacity(0.15)
            : AppColors.surfaceDim,
        border: Border.all(color: fg, width: 1.5),
      ),
      child: Icon(
        Icons.person_outline_rounded,
        size: size * 0.55,
        color: fg,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Leaderboard — Stack + AnimatedPositioned so rows slide between ranks
// ---------------------------------------------------------------------------

class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({required this.entries, required this.total});

  final List<SessionModel> entries;
  final int total;

  static const double _rowHeight = 64;
  static const double _rowGap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Leaderboard',
            style: AppTypography.title
                .copyWith(color: AppColors.textSecondary, fontSize: 18),
          ),
          const SizedBox(height: AppSpacing.md),
          if (entries.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.leaderboard_rounded,
                      size: 48,
                      color: AppColors.textTertiary.withOpacity(0.5),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Ranks 4+ will appear here',
                      style: AppTypography.subtitle.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Only the top three so far.',
                      style: AppTypography.bodyMuted,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  // Stack lets rows tween between positions when a rank
                  // shuffle happens; AnimatedPositioned does the rest.
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      for (var i = 0; i < entries.length; i++)
                        AnimatedPositioned(
                          key: ValueKey('lb-${entries[i].uid}'),
                          duration: const Duration(milliseconds: 520),
                          curve: Curves.easeOutCubic,
                          left: 0,
                          right: 0,
                          top: i * (_rowHeight + _rowGap),
                          height: _rowHeight,
                          child: AnimatedEntry(
                            index: i,
                            stagger: const Duration(milliseconds: 50),
                            offset: const Offset(0.08, 0),
                            child: _RankRow(
                              rank: i + 4,
                              session: entries[i],
                              total: total,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.session,
    required this.total,
  });

  final int rank;
  final SessionModel session;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.input,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '$rank',
              style: AppTypography.title
                  .copyWith(color: AppColors.textTertiary, fontSize: 22),
            ),
          ),
          ProfileAvatar(
            name: session.scannerName.isNotEmpty
                ? session.scannerName
                : 'Player',
            size: 36,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _displayName(session),
              style: AppTypography.subtitle.copyWith(fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedNumber(
                value: session.completedCount,
                style: AppTypography.subtitle.copyWith(
                  color: AppColors.accent,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                ' / $total',
                style: AppTypography.subtitle.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ambient background — slow accent gradient sweep
// ---------------------------------------------------------------------------

class _AmbientBackground extends StatefulWidget {
  const _AmbientBackground();

  @override
  State<_AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<_AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    // Long period so the motion stays calm — projector audiences shouldn't
    // notice it consciously, just feel it.
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        // Two slow-drifting radial glows offset on a Lissajous-ish path.
        final dx1 = math.sin(t * 2 * math.pi) * 0.4;
        final dy1 = math.cos(t * 2 * math.pi) * 0.3;
        final dx2 = math.cos(t * 2 * math.pi + 1.1) * 0.35;
        final dy2 = math.sin(t * 2 * math.pi * 0.7 + 0.4) * 0.45;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(dx1, dy1),
              radius: 1.0,
              colors: [
                AppColors.accent.withOpacity(0.08),
                Colors.transparent,
              ],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(dx2, dy2),
                radius: 1.2,
                colors: [
                  AppColors.accentDark.withOpacity(0.06),
                  Colors.transparent,
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers + holding screen
// ---------------------------------------------------------------------------

String _displayName(SessionModel s) =>
    s.scannerName.isNotEmpty ? s.scannerName : 'Player ${s.uid.substring(0, 4)}';

class _AuthHoldingScreen extends StatelessWidget {
  const _AuthHoldingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.accent),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Connecting scoreboard…',
              style: AppTypography.bodyMuted,
            ),
          ],
        ),
      ),
    );
  }
}
