import 'package:flutter/material.dart';
import '../models/user.dart';
import '../const/app_config.dart';
import 'dart:math' as math;

class BingoGrid extends StatelessWidget {
  final List<BingoBox> boxes;
  final Function(int)? onBoxTap;
  final User? currentUser;

  const BingoGrid({
    super.key,
    required this.boxes,
    this.onBoxTap,
    this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    // Safety check for empty boxes list
    if (boxes.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF00FF88),
        ),
      );
    }
    
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: AppConfig.questionsCount,
      itemBuilder: (context, index) {
        // Additional safety check for index bounds
        if (index >= boxes.length) {
          return const SizedBox.shrink();
        }
        
        final box = boxes[index];
        final isScannedByCurrentUser = currentUser?.scannedBoxes.contains(box.id) ?? false;
        
        return BingoBoxWidget(
          box: box,
          isScannedByCurrentUser: isScannedByCurrentUser,
          onTap: onBoxTap != null ? () => onBoxTap!(box.id) : null,
          isEnabled: currentUser != null,
        );
      },
    );
  }
}

class BingoBoxWidget extends StatelessWidget {
  final BingoBox box;
  final bool isScannedByCurrentUser;
  final VoidCallback? onTap;
  final bool isEnabled;

  const BingoBoxWidget({
    super.key,
    required this.box,
    required this.isScannedByCurrentUser,
    this.onTap,
    required this.isEnabled,
  });

  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Scanned profile with image (by current user only)
    if (box.scannedBy != null && _isValidImageUrl(box.scannedByProfilePicture)) {
      return GestureDetector(
        onTap: isEnabled ? onTap : null,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isScannedByCurrentUser ? const Color(0xFF00FF88) : Colors.blue,
                  width: 3,
                ),
              ),
              child: ClipOval(
                child: Image.network(
                  box.scannedByProfilePicture!,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildFallbackAvatar();
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: const Color(0xFF1A3A35),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / 
                                loadingProgress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2,
                          color: const Color(0xFF00FF88),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Checkmark indicator for connected profiles
            if (isScannedByCurrentUser)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF0D1F1C),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Color(0xFF0D1F1C),
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Scanned profile without valid image (by anyone)
    if (box.scannedBy != null) {
      return GestureDetector(
        onTap: isEnabled ? onTap : null,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isScannedByCurrentUser ? const Color(0xFF00FF88) : Colors.blue,
                  width: 3,
                ),
                color: const Color(0xFF1A3A35),
              ),
              child: _buildFallbackAvatar(),
            ),
            if (isScannedByCurrentUser)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF0D1F1C),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Color(0xFF0D1F1C),
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Empty slot with dashed circle
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: CustomPaint(
        painter: DashedCirclePainter(
          color: Colors.white.withOpacity(0.2),
          strokeWidth: 2.5,
          dashWidth: 8,
          dashSpace: 6,
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
          ),
          child: Center(
            child: Icon(
              Icons.add,
              color: Colors.white.withOpacity(0.3),
              size: 32,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar() {
    final name = box.scannedByName;
    final initial = name?.isNotEmpty == true ? name![0].toUpperCase() : '?';
    
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Color(0xFF00FF88),
        ),
      ),
    );
  }
}

// Custom painter for dashed circle border
class DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  DashedCirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashWidth + dashSpace)).floor();

    for (int i = 0; i < dashCount; i++) {
      final startAngle = (i * (dashWidth + dashSpace) / radius);
      final sweepAngle = dashWidth / radius;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}