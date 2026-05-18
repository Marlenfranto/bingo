import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';
import '../providers/app_providers.dart';
import '../const/questions.dart';
import '../const/app_config.dart';
import 'dart:convert';
import 'dart:math' as math;

class CameraScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? args;
  
  const CameraScreen({super.key, this.args});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with TickerProviderStateMixin {
  MobileScannerController cameraController = MobileScannerController();
  late AnimationController _successAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  bool _isScanning = true;
  bool _showSuccessAnimation = false;
  int? _boxId;
  int? _questionIndex;
  String? _questionText;
  
  // Security constants
  static const String _qrSignature = 'BINGO_USER_V1';
  static const String _appIdentifier = 'namma_bingo_app';

  @override
  void initState() {
    super.initState();
    if (widget.args != null) {
      _boxId = widget.args!['boxId'] as int?;
      _questionIndex = widget.args!['questionIndex'] as int?;
      _questionText = widget.args!['questionText'] as String?;
    }
    
    // Initialize animation controllers
    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _successAnimationController,
      curve: Curves.easeOutBack,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  // Security validation methods
  bool _isValidBingoQR(String qrData) {
    try {
      // Try to decode as base64 first (for encoded QR codes)
      String decodedData = qrData;
      try {
        final bytes = base64Decode(qrData);
        decodedData = utf8.decode(bytes);
      } catch (e) {
        // If base64 decode fails, use original data
      }

      // Check if it's JSON format
      final data = json.decode(decodedData);
      
      // Validate required fields for bingo user QR
      return data is Map<String, dynamic> &&
             data['app'] == _appIdentifier &&
             data['type'] == 'bingo_user' &&
             data['signature'] == _qrSignature &&
             data['name'] is String &&
             data['name'].toString().trim().isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> _triggerSuccessAnimation() async {
    if (!mounted) return;
    
    // Trigger haptic feedback and vibration
    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(
          pattern: [0, 200, 100, 200], // Success pattern: pause, vibrate, pause, vibrate
          intensities: [0, 255, 0, 255],
        );
      }
    } catch (e) {
      // Vibration not available on this device
    }
    
    // Show success animation overlay
    setState(() {
      _showSuccessAnimation = true;
    });
    
    // Start animation
    _successAnimationController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _pulseAnimationController.forward();
    
    // Hide animation after delay
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (mounted) {
      setState(() {
        _showSuccessAnimation = false;
      });
      _successAnimationController.reset();
      _pulseAnimationController.reset();
    }
  }

  Widget _buildSuccessAnimationOverlay() {
    return AnimatedBuilder(
      animation: _successAnimationController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF00FF88).withOpacity(_scaleAnimation.value),
                Color(0xFF00CC66).withOpacity(_scaleAnimation.value),
                Color(0xFF00AA44).withOpacity(_scaleAnimation.value),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Ripple effect background
              ...List.generate(3, (index) {
                return Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _successAnimationController,
                    builder: (context, child) {
                      final delay = index * 0.2;
                      final animValue = math.max(0.0, (_scaleAnimation.value - delay) / (1.0 - delay));
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3 * (1 - animValue)),
                            width: 2,
                          ),
                        ),
                        transform: Matrix4.identity()..scale(animValue * 3.0),
                        child: const SizedBox.expand(),
                      );
                    },
                  ),
                );
              }),
              
              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Check icon
                    Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 80,
                          color: Color(0xFF00FF88),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Success text with typewriter effect
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        final text = "SUCCESS!";
                        final visibleLength = (_pulseAnimation.value * text.length).floor();
                        final visibleText = text.substring(0, visibleLength);
                        
                        return Column(
                          children: [
                            Text(
                              visibleText,
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 4.0,
                                shadows: [
                                  Shadow(
                                    blurRadius: 10,
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (_pulseAnimation.value > 0.7) // Show subtitle after main text
                              Transform.scale(
                                scale: (_pulseAnimation.value - 0.7) / 0.3,
                                child: Text(
                                  "Connection Established",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              // Floating particles
              ...List.generate(12, (index) {
                final angle = (index * 30) * (3.14159 / 180);
                return AnimatedBuilder(
                  animation: _successAnimationController,
                  builder: (context, child) {
                    final progress = _scaleAnimation.value;
                    final radius = 100.0 + (progress * 200.0);
                    final opacity = progress * (1 - progress) * 4; // Fade in and out
                    
                    return Positioned(
                      left: MediaQuery.of(context).size.width / 2 + 
                          (radius * math.cos(angle + progress * 2)) - 10,
                      top: MediaQuery.of(context).size.height / 2 + 
                          (radius * math.sin(angle + progress * 2)) - 10,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(opacity),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(opacity * 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showUnauthorizedQRWarning() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF0D1F1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: Color(0xFFFF6B35),
            width: 2,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0D1F1C),
                const Color(0xFF1A3A35).withOpacity(0.8),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon with animation
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF6B35).withOpacity(0.1),
                  border: Border.all(
                    color: const Color(0xFFFF6B35),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Color(0xFFFF6B35),
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              const Text(
                'Unauthorized QR Code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Message
              const Text(
                'This QR code is not from the Bingo app. Please scan only valid user QR codes to make connections.',
                style: TextStyle(
                  color: Color(0xFFB0BEC5),
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _isScanning = true;
                    });
                    ref.read(scanStatusProvider.notifier).state = null;
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    foregroundColor: const Color(0xFF0D1F1C),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    _successAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture barcodeCapture) async {
    if (!_isScanning) return;

    final List<Barcode> barcodes = barcodeCapture.barcodes;
    if (barcodes.isEmpty) return;

    final String? qrData = barcodes.first.rawValue;
    if (qrData == null) return;

    setState(() {
      _isScanning = false;
    });

    await _processQrData(qrData);
  }

  Future<void> _processQrData(String qrData) async {
    try {
      // Show scanning status
      ref.read(scanStatusProvider.notifier).state = 'Processing QR code...';
      
      // First validate if this is a valid bingo QR code
      if (!_isValidBingoQR(qrData)) {
        _showUnauthorizedQRWarning();
        return;
      }

      // Decode QR data securely
      String decodedData = qrData;
      try {
        // Try base64 decode first
        final bytes = base64Decode(qrData);
        decodedData = utf8.decode(bytes);
      } catch (e) {
        // Use original data if not base64 encoded
      }

      // Parse validated QR data to extract user information
      final data = json.decode(decodedData);
      
      String scannedUserName = data['name'] ?? 'Unknown User';
      String? profilePictureUrl = data['profilePictureUrl'];
      String? linkedInUrl = data['linkedinUrl'];
      String scannedUserId = data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();

      // Get current user
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        throw 'Please set up your profile first';
      }

      // Prevent self-scanning
      if (scannedUserId == currentUser.id) {
        _showSelfScanError();
        return;
      }

      // Check for repetitive person scanning if not allowed
      if (!AppConfig.allowRepetitivePersonScan) {
        final bingoBoxes = ref.read(bingoBoxesProvider);
        final hasAlreadyScanned = bingoBoxes.any(
          (box) => box.scannedBy == scannedUserId && box.isSelected,
        );
        
        if (hasAlreadyScanned) {
          _showAlreadyScannedError(scannedUserName);
          return;
        }
        
        // Also check if same user is trying to scan the same person again (only when repetitive scan is not allowed)
        final currentUserAlreadyScannedThisPerson = bingoBoxes.any(
          (box) => box.scannedBy == scannedUserId && 
                   box.isSelected && 
                   currentUser.scannedBoxes.contains(box.id),
        );
        
        if (currentUserAlreadyScannedThisPerson && !AppConfig.allowSameUserScan) {
          _showSameUserScanError(scannedUserName);
          return;
        }
      }

      // Find an available box to assign this scan to
      int? availableBoxId = _boxId;
      if (availableBoxId == null) {
        // Find the first available box
        for (int i = 1; i <= 25; i++) {
          if (!currentUser.scannedBoxes.contains(i)) {
            availableBoxId = i;
            break;
          }
        }
        
        if (availableBoxId == null) {
          throw 'All boxes are already filled! You\'ve reached the maximum connections.';
        }
      } else {
        // Check if this specific box was already scanned
        if (currentUser.scannedBoxes.contains(availableBoxId)) {
          throw 'You\'ve already scanned this box!';
        }
      }

      // Update scanning status
      ref.read(scanStatusProvider.notifier).state = 'Connecting...';

      // Simulate connection processing
      await Future.delayed(const Duration(seconds: 1));

      // Mark box as scanned
      await ref.read(currentUserProvider.notifier).addScannedBox(availableBoxId);
      
      // Get the question for this box
      String questionAnswered = '';
      if (_questionText != null) {
        // Use the specific question from the Scan to Connect button
        questionAnswered = _questionText!;
      } else if (availableBoxId > 0 && availableBoxId <= Questions.flutterEventQuestions.length) {
        questionAnswered = Questions.flutterEventQuestions[availableBoxId - 1];
      }
      
      ref.read(bingoBoxesProvider.notifier).selectBox(
        availableBoxId, 
        scannedUserId, 
        scannedUserName, 
        profilePictureUrl, 
        linkedInUrl: linkedInUrl,
        questionAnswered: questionAnswered
      );

      // Show success message
      ref.read(scanStatusProvider.notifier).state = 'Connected successfully!';
      
      // Trigger success animation and vibration
      await _triggerSuccessAnimation();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Successfully connected with $scannedUserName!'),
                    ),
                  ],
                ),
                if (questionAnswered.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Question answered:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    questionAnswered,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Navigate back after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            context.go('/');
          }
        });
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.error, color: Colors.red, size: 64),
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  setState(() {
                    _isScanning = true; // Resume scanning
                  });
                },
                child: const Text('Try Again'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Go back to home
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      }
    } finally {
      ref.read(scanStatusProvider.notifier).state = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanStatus = ref.watch(scanStatusProvider);
    
    // Get the question for the specific box being scanned
    String currentQuestion = 'Tap a specific box to see its question';
    
    if (_questionText != null) {
      // Use the specific question from Scan to Connect button
      currentQuestion = _questionText!;
    } else if (_boxId != null && _boxId! > 0 && _boxId! <= Questions.flutterEventQuestions.length) {
      currentQuestion = Questions.flutterEventQuestions[_boxId! - 1];
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A3A2E),
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview (full screen background)
            Positioned.fill(
              child: MobileScanner(
                controller: cameraController,
                onDetect: _onDetect,
              ),
            ),
            
            // Dark overlay
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            
            // Content overlay
            Column(
              children: [
                // Top close button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => context.go('/'),
                        icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                      ),
                      IconButton(
                        onPressed: () => cameraController.toggleTorch(),
                        icon: const Icon(Icons.flashlight_on, color: Colors.white70, size: 28),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(flex: 2),
                
                // Scanning frame with rounded corners
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Main scanning frame
                      Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF00FF87),
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      
                      // Corner indicators
                      Positioned(
                        top: -5,
                        left: -5,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: const Color(0xFF00FF87), width: 4),
                              left: BorderSide(color: const Color(0xFF00FF87), width: 4),
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(32),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -5,
                        right: -5,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: const Color(0xFF00FF87), width: 4),
                              right: BorderSide(color: const Color(0xFF00FF87), width: 4),
                            ),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(32),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -5,
                        left: -5,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: const Color(0xFF00FF87), width: 4),
                              left: BorderSide(color: const Color(0xFF00FF87), width: 4),
                            ),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(32),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -5,
                        right: -5,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: const Color(0xFF00FF87), width: 4),
                              right: BorderSide(color: const Color(0xFF00FF87), width: 4),
                            ),
                            borderRadius: const BorderRadius.only(
                              bottomRight: Radius.circular(32),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Scanning status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF00FF87), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00FF87),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        scanStatus ?? 'SCANNING FOR BINGO BADGE',
                        style: const TextStyle(
                          color: Color(0xFF00FF87),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(flex: 1),
                
                // Instruction text
                const Text(
                  'Align QR code within the\nframe',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Target info card - Full question display
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A4A3E).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF00FF87).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF87).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          color: Color(0xFF00FF87),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Target Question',
                                  style: TextStyle(
                                    color: Color(0xFF00FF87),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_questionIndex != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00FF87),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_questionIndex! + 1}/15',
                                      style: const TextStyle(
                                        color: Color(0xFF0D1F1C),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF00FF87).withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                currentQuestion,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
            
            // Loading overlay
            if (scanStatus != null && scanStatus != 'SCANNING FOR BINGO BADGE')
              Positioned.fill(
                child: Container(
                  color: Colors.black87,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A4A3E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF00FF87)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: Color(0xFF00FF87),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            scanStatus,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Success animation overlay
              if (_showSuccessAnimation)
                Positioned.fill(
                  child: _buildSuccessAnimationOverlay(),
                ),
          ],
        ),
      ),
    );
  }

  void _showSelfScanError() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF0D1F1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: Color(0xFFFF4444),
            width: 2,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0D1F1C),
                const Color(0xFF2D1B1B).withOpacity(0.8),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF4444).withOpacity(0.1),
                  border: Border.all(
                    color: const Color(0xFFFF4444),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.block,
                  color: Color(0xFFFF4444),
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              const Text(
                'Cannot Scan Your Own QR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Message
              const Text(
                'You cannot scan your own QR code to make a connection. Please ask someone else to scan your code instead.',
                style: TextStyle(
                  color: Color(0xFFB0BEC5),
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _isScanning = true;
                    });
                    ref.read(scanStatusProvider.notifier).state = null;
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    foregroundColor: const Color(0xFF0D1F1C),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continue Scanning',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    setState(() {
      _isScanning = true;
    });
    ref.read(scanStatusProvider.notifier).state = null;
  }

  void _showAlreadyScannedError(String userName) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF0D1F1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: Color(0xFFFF9800),
            width: 2,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0D1F1C),
                const Color(0xFF2D2116).withOpacity(0.8),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF9800).withOpacity(0.1),
                  border: Border.all(
                    color: const Color(0xFFFF9800),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.person_off,
                  color: Color(0xFFFF9800),
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              const Text(
                'Already Connected',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Message
              Text(
                'You have already connected with $userName. Each person can only be scanned once.',
                style: const TextStyle(
                  color: Color(0xFFB0BEC5),
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _isScanning = true;
                    });
                    ref.read(scanStatusProvider.notifier).state = null;
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    foregroundColor: const Color(0xFF0D1F1C),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Scan Someone Else',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    setState(() {
      _isScanning = true;
    });
    ref.read(scanStatusProvider.notifier).state = null;
  }

  void _showSameUserScanError(String userName) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF0D1F1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: Color(0xFF9C27B0),
            width: 2,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0D1F1C),
                const Color(0xFF2D1B2D).withOpacity(0.8),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF9C27B0).withOpacity(0.1),
                  border: Border.all(
                    color: const Color(0xFF9C27B0),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.repeat_rounded,
                  color: Color(0xFF9C27B0),
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              const Text(
                'Duplicate Scan Detected',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Message
              Text(
                'You have already scanned $userName. Please scan someone new to continue building your network.',
                style: const TextStyle(
                  color: Color(0xFFB0BEC5),
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _isScanning = true;
                    });
                    ref.read(scanStatusProvider.notifier).state = null;
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    foregroundColor: const Color(0xFF0D1F1C),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Find New Connection',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    setState(() {
      _isScanning = true;
    });
    ref.read(scanStatusProvider.notifier).state = null;
  }

}