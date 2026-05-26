import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/env.dart';
import '../../core/logger.dart';
import '../../core/result.dart';
import '../../data/repositories/session_repository.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import '../auth/auth_providers.dart';
import 'qr_payload.dart';
import 'widgets/scan_success_overlay.dart';

/// Scans a Namma Bingo QR and records it into the current player's session.
///
/// Performance + reliability notes:
///   - `detectionSpeed: normal` + `detectionTimeoutMs: 400` rate-limits the
///     callback to avoid burning CPU on low-end devices and avoids
///     double-processing the same QR.
///   - `formats: [qrCode]` short-circuits other barcode parsers.
///   - `returnImage: false` (default) — we don't need the raw frame bytes.
///   - `WidgetsBindingObserver` stops the camera when the app backgrounds
///     so we don't hold the camera handle while not visible.
///
/// Required route extras (Map<String, dynamic>):
///   slotIndex     int
///   questionId    String
///   questionText  String
class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key, required this.args});

  final Map<String, dynamic>? args;

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _flashController;

  bool _processing = false;
  String? _statusMessage;
  late final int _slotIndex;
  late final String _questionId;
  late final String _questionText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = MobileScannerController(
      // noDuplicates: each unique QR fires the detect callback once, period.
      // Better than (normal + detectionTimeoutMs) for a one-shot scan flow
      // — no missed first-detection-then-throttled-out race, no need to pick
      // a timeout that's "long enough but not too long".
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
      facing: CameraFacing.back,
      torchEnabled: false,
      returnImage: false,
      // Force a high-res frame on platforms that support it (Android).
      // Default platform resolutions are often 640x480, which misses dense
      // QRs at arm's length. 1080p makes module edges crisp.
      cameraResolution: const Size(1920, 1080),
    );

    _flashController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    final args = widget.args ?? const <String, dynamic>{};
    _slotIndex = args['slotIndex'] as int? ?? 0;
    _questionId = args['questionId'] as String? ?? '';
    _questionText = args['questionText'] as String? ?? '';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flashController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Don't hold the camera while backgrounded — fixes UX on iOS where
    // returning to the app would otherwise show a frozen frame.
    switch (state) {
      case AppLifecycleState.resumed:
        _controller.start();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _controller.stop();
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;

    // mobile_scanner sometimes packs multiple barcodes into one capture
    // (e.g., a QR poster + a sticker in frame). Pick the first one that
    // looks like ours instead of blindly taking [0], which would dialog-spam
    // the user with "This QR isn't from Namma Bingo." every time.
    QrPayload? payload;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null || raw.isEmpty) continue;
      final decoded = QrPayload.decode(raw);
      if (decoded case Ok(:final value)) {
        payload = value;
        break;
      }
    }
    // Nothing in frame is a valid Bingo QR — keep the camera live and let
    // the user keep aiming. No dialog interruption for noise QRs.
    if (payload == null) return;

    setState(() {
      _processing = true;
      _statusMessage = 'Reading QR…';
    });
    await _controller.stop();

    final uid = ref.read(currentUidProvider);
    final me = ref.read(currentUserProvider).valueOrNull;
    if (uid == null || me == null) {
      await _showError('Not signed in');
      return;
    }
    if (payload.uid == uid) {
      await _showError("That's your own QR.");
      return;
    }

    setState(() => _statusMessage = 'Adding to your board…');

    final res = await ref.read(sessionRepositoryProvider).recordScan(
          gameId: Env.activeGameId,
          scannerUid: uid,
          scannerName: me.name,
          slotIndex: _slotIndex,
          scannedUid: payload.uid,
          scannedName: payload.name,
          scannedLinkedinUrl: payload.linkedinUrl,
          questionId: _questionId,
          questionText: _questionText,
          allowRepetitivePersonScan: Env.allowRepetitivePersonScan,
        );

    if (res case Err(:final error)) {
      await _showError(error.message);
      return;
    }

    // Visual + haptic success lead-in (green tint over the camera).
    unawaited(HapticFeedback.mediumImpact());
    await _flashController.forward(from: 0);
    if (!mounted) return;

    // Trophy moment — full-screen celebration. Returns when the user taps
    // Continue, taps outside, or the auto-dismiss timer fires.
    await showScanSuccessOverlay(
      context,
      scannedName: payload.name,
      slotIndex: _slotIndex,
      questionText: _questionText,
    );
    if (!mounted) return;
    context.pop(true);
  }

  Future<void> _showError(String message) async {
    AppLogger.w('Scan rejected: $message');
    if (!mounted) return;
    setState(() {
      _processing = false;
      _statusMessage = null;
    });
    final retry = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Could not scan'),
        content: Text(message, style: AppTypography.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (retry == true) {
      await _controller.start();
    } else {
      context.pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan a QR'),
        actions: [
          IconButton(
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch_outlined),
            tooltip: 'Switch camera',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, _) =>
                _CameraError(errorCode: error.errorCode.name),
          ),
          // Dim the area outside the cutout so the user's eye snaps to the
          // scanning region. Helps them aim, which helps the camera read.
          const IgnorePointer(child: _ScannerOverlay()),
          const _ScannerCutout(),
          const _ScannerHint(),
          _SuccessFlash(controller: _flashController),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: _PromptCard(
                  slotNumber: _slotIndex,
                  question: _questionText,
                  status: _statusMessage,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reticle border that gently pulses its glow + four corner brackets to
/// signal "the camera is looking". Visual heartbeat helps users understand
/// they need to hold the QR inside the frame.
class _ScannerCutout extends StatefulWidget {
  const _ScannerCutout();

  @override
  State<_ScannerCutout> createState() => _ScannerCutoutState();
}

class _ScannerCutoutState extends State<_ScannerCutout>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) {
            final t = _pulse.value;
            return Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.6 + t * 0.4),
                  width: 2,
                ),
                borderRadius: AppRadius.all,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentGlow.withOpacity(0.4 + t * 0.5),
                    blurRadius: 16 + t * 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Stack(
                children: [
                  _CornerBracket(top: -1, left: -1),
                  _CornerBracket(top: -1, right: -1, mirrorX: true),
                  _CornerBracket(bottom: -1, left: -1, mirrorY: true),
                  _CornerBracket(
                    bottom: -1,
                    right: -1,
                    mirrorX: true,
                    mirrorY: true,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One of the four "L" brackets at the corners of the scanning reticle.
class _CornerBracket extends StatelessWidget {
  const _CornerBracket({
    this.top,
    this.bottom,
    this.left,
    this.right,
    this.mirrorX = false,
    this.mirrorY = false,
  });

  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final bool mirrorX;
  final bool mirrorY;

  @override
  Widget build(BuildContext context) {
    final radius = const Radius.circular(12);
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          mirrorX ? -1.0 : 1.0,
          mirrorY ? -1.0 : 1.0,
          1.0,
        ),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            border: Border(
              top: const BorderSide(color: AppColors.accent, width: 4),
              left: const BorderSide(color: AppColors.accent, width: 4),
            ),
            borderRadius: BorderRadius.only(topLeft: radius),
          ),
        ),
      ),
    );
  }
}

/// Darkens the area outside the scanning reticle so the user's eye is
/// pulled to the framed region. Uses a simple painter to "punch out" the
/// reticle — cheaper than a Stack of four rectangles.
class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _OverlayPainter(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  static const _reticleSize = 260.0;
  static const _reticleRadius = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final reticle = Rect.fromCenter(
      center: rect.center,
      width: _reticleSize,
      height: _reticleSize,
    );
    final path = Path()
      ..addRect(rect)
      ..addRRect(
          RRect.fromRectAndRadius(reticle, const Radius.circular(_reticleRadius)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withOpacity(0.55),
    );
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => false;
}

/// Below-the-reticle hint that gives the user something useful to do when
/// scanning takes more than a moment. Shown immediately, not on a timer,
/// because intermittent users skim hints whenever they glance.
class _ScannerHint extends StatelessWidget {
  const _ScannerHint();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, 0.55),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: AppRadius.button,
          ),
          child: Text(
            'Center the QR · hold steady',
            style: AppTypography.caption.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Fast green tint when a scan resolves; provides instant visual feedback
/// before the screen pops.
class _SuccessFlash extends StatelessWidget {
  const _SuccessFlash({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final t = controller.value;
          return Container(
            color: AppColors.accent.withOpacity(t * 0.45),
          );
        },
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.errorCode});

  final String errorCode;

  @override
  Widget build(BuildContext context) {
    final isPermission = errorCode.toLowerCase().contains('permission');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPermission ? Icons.lock_outline : Icons.videocam_off_outlined,
              size: 56,
              color: Colors.white70,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isPermission ? 'Camera permission denied' : 'Camera unavailable',
              style: AppTypography.subtitle.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isPermission
                  ? 'Open settings and grant camera access to scan QR codes.'
                  : 'Error code: $errorCode',
              style: AppTypography.bodyMuted.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.slotNumber,
    required this.question,
    required this.status,
  });

  final int slotNumber;
  final String question;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.accent),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Slot $slotNumber',
                  style: AppTypography.label.copyWith(color: AppColors.accent),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (status != null)
                Expanded(
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(status!,
                            style: AppTypography.caption,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(question, style: AppTypography.body),
        ],
      ),
    );
  }
}
