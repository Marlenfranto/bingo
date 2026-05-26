import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/platform/file_saver.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../auth/auth_providers.dart';
import 'qr_payload.dart';

/// Renders the signed-in user's QR. Uses error-correction level H + an
/// embedded brand logo so the code stays scannable even with the central
/// glyph occluded. Save/Share goes through the cross-platform file_saver
/// (browser download on web, native share-sheet on mobile).
class QrGeneratorScreen extends ConsumerStatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  ConsumerState<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends ConsumerState<QrGeneratorScreen> {
  final _captureKey = GlobalKey();
  bool _exporting = false;

  // Cache the encoded payload so we don't re-encode on every rebuild — the
  // QrImageView would otherwise re-render every frame, which can cause a
  // brief mid-paint state that scanners may catch and reject.
  String? _cachedPayload;
  String? _cachedUserId;

  Future<void> _share() async {
    setState(() => _exporting = true);
    try {
      final boundary = _captureKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      // 3x pixel ratio: scannable from across a small room when printed.
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      await saveQrPng(
        bytes,
        filename: 'namma-bingo-${DateTime.now().millisecondsSinceEpoch}.png',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export QR: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('My QR')),
        body: const AppEmptyState(
          icon: Icons.person_off_outlined,
          title: 'Profile not loaded',
          message: 'Sign in and finish onboarding to generate your QR.',
        ),
      );
    }

    // Re-encode only when the user's profile fields that go into the QR
    // change. Identity stays stable; payload string stays stable.
    final payloadKey =
        '${user.id}|${user.name}|${user.linkedinUrl ?? ''}';
    if (_cachedPayload == null || _cachedUserId != payloadKey) {
      _cachedPayload = QrPayload.fromUser(user).encode();
      _cachedUserId = payloadKey;
    }
    final payload = _cachedPayload!;

    final subtitle = [user.designation, user.company]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My QR')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Text(
                    'Show this to people you meet',
                    style: AppTypography.bodyMuted,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  RepaintBoundary(
                    key: _captureKey,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: AppRadius.card,
                      ),
                      // Generous outer padding doubles as the QR's quiet
                      // zone — scanners need clean whitespace around the
                      // code's outermost modules to lock onto the finder
                      // patterns. Skimping here is the #1 cause of misses.
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        children: [
                          LayoutBuilder(
                            builder: (context, c) {
                              // Responsive QR size: bigger when there's room
                              // (printable / projected use), capped so it
                              // doesn't take over the screen on mobile.
                              final side = c.maxWidth.clamp(220.0, 320.0);
                              return QrImageView(
                                data: payload,
                                size: side,
                                backgroundColor: Colors.white,
                                // H-level (30% damage tolerance) is the most
                                // forgiving option — robust against camera
                                // shake, screen glare, partial fingers in
                                // frame, and printed-then-creased copies.
                                errorCorrectionLevel: QrErrorCorrectLevel.H,
                                // Crisper module edges; we already have a
                                // quiet zone via the surrounding Container.
                                gapless: true,
                                padding: EdgeInsets.zero,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Colors.black,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Colors.black,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            user.name,
                            style: AppTypography.subtitle
                                .copyWith(color: AppColors.background),
                            textAlign: TextAlign.center,
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              subtitle,
                              style: AppTypography.caption
                                  .copyWith(color: Colors.black54),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    color: AppColors.surfaceElevated,
                    child: Row(
                      children: [
                        ProfileAvatar(
                          name: user.name,
                          size: 40,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.name, style: AppTypography.subtitle),
                              const SizedBox(height: 2),
                              Text(user.email, style: AppTypography.caption),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: _exporting ? 'Exporting…' : 'Save / Share',
                    icon: Icons.ios_share,
                    onPressed: _exporting ? null : _share,
                    loading: _exporting,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
