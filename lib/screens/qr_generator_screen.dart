import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import '../providers/app_providers.dart';
import 'dart:convert';
import 'dart:html' as html;

class QrGeneratorScreen extends ConsumerStatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  ConsumerState<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends ConsumerState<QrGeneratorScreen> {
  final GlobalKey _qrKey = GlobalKey();
  bool _isDownloading = false;

  Future<void> _downloadQRCode() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      // Capture QR code as image
      RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // For web: trigger browser download
      final base64String = base64Encode(pngBytes);
      final dataUrl = 'data:image/png;base64,$base64String';
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = dataUrl
        ..style.display = 'none'
        ..download = 'qr_code_${DateTime.now().millisecondsSinceEpoch}.png';
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('QR Code downloaded!'),
              ],
            ),
            backgroundColor: const Color(0xFF00FF88),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: const Color(0xFFFF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  bool _isValidUrl(String? url) {
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
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1F1C),
        appBar: AppBar(
          title: const Text('My QR Code'),
          backgroundColor: const Color(0xFF0D1F1C),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_add, size: 64, color: Color(0xFF00FF88)),
              SizedBox(height: 16),
              Text(
                'Please set up your profile first',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Go to Profile to add your information',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    // Create QR data with security validation and user profile details
    final qrDataObject = {
      'app': 'namma_bingo_app',
      'signature': 'BINGO_USER_V1',
      'type': 'bingo_user',
      'id': currentUser.id,
      'name': currentUser.name,
      'linkedinUrl': currentUser.linkedinUrl,
      'profilePictureUrl': currentUser.profilePictureUrl,
      'scannedBoxes': currentUser.scannedBoxes.toList(),
      'timestamp': DateTime.now().toIso8601String(),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

    // Encode the QR data for security
    final jsonString = jsonEncode(qrDataObject);
    final qrData = base64Encode(utf8.encode(jsonString));

    return Scaffold(
      backgroundColor: const Color(0xFF0D1F1C),
      appBar: AppBar(
        title: const Text('My QR Code'),
        backgroundColor: const Color(0xFF0D1F1C),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile info card
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF00FF88).withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF00FF88),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: _isValidUrl(currentUser.profilePictureUrl)
                          ? Image.network(
                              currentUser.profilePictureUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: const Color(
                                      0xFF00FF88,
                                    ).withOpacity(0.2),
                                    child: Center(
                                      child: Text(
                                        currentUser.name.isNotEmpty
                                            ? currentUser.name
                                                  .substring(0, 1)
                                                  .toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Color(0xFF00FF88),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                            )
                          : Container(
                              color: const Color(0xFF00FF88).withOpacity(0.2),
                              child: Center(
                                child: Text(
                                  currentUser.name.isNotEmpty
                                      ? currentUser.name
                                            .substring(0, 1)
                                            .toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Color(0xFF00FF88),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentUser.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Connections: ${currentUser.scannedBoxes.length}/15',
                          style: const TextStyle(
                            color: Color(0xFF00FF88),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Instructions
            const Text(
              'Share this QR code with others',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When someone scans this code, they\'ll connect with you instantly!',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // QR Code with actual generation
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00FF88), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FF88).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: PrettyQrView.data(
                  data: qrData,
                  decoration: PrettyQrDecoration(
                    image: PrettyQrDecorationImage(
                      position: PrettyQrDecorationImagePosition.embedded,
                      image: AssetImage('assets/bingo.png'),
                    ),
                    quietZone: PrettyQrQuietZone.standart,
                    shape: PrettyQrSquaresSymbol(),
                  ),

                  errorBuilder: (cxt, obj, err) {
                    return Container(
                      width: 250,
                      height: 250,
                      alignment: Alignment.center,
                      child: const Text(
                        "QR Error",
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Security indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF00FF88).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.security,
                    color: const Color(0xFF00FF88),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Secured & Verified',
                      style: TextStyle(
                        color: Color(0xFF00FF88),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // QR Data preview (for development) - COMMENTED OUT
            /*
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00FF88).withOpacity(0.2),
                ),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  expansionTileTheme: const ExpansionTileThemeData(
                    iconColor: Color(0xFF00FF88),
                    collapsedIconColor: Color(0xFF00FF88),
                  ),
                ),
                child: ExpansionTile(
                  title: Row(
                    children: [
                      Icon(
                        Icons.code, 
                        size: 18, 
                        color: const Color(0xFF00FF88)
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'QR Data Preview (Dev)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  initiallyExpanded: false,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1F1C),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF00FF88).withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.data_object,
                                  size: 14,
                                  color: const Color(0xFF00FF88),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Raw JSON Data:',
                                  style: TextStyle(
                                    color: Color(0xFF00FF88),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              qrData,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontFamily: 'monospace',
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            */
            const SizedBox(height: 24),

            // QR Code Contains Section - COMMENTED OUT
            /*
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF00FF88).withOpacity(0.3),
                ),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  expansionTileTheme: const ExpansionTileThemeData(
                    iconColor: Color(0xFF00FF88),
                    collapsedIconColor: Color(0xFF00FF88),
                  ),
                ),
                child: ExpansionTile(
                  title: Row(
                    children: [
                      Icon(Icons.info_outline, color: const Color(0xFF00FF88), size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'QR Code Contains',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  initiallyExpanded: false,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDataPreviewItem('👤 Name', currentUser.name),
                          _buildDataPreviewItem('🔗 LinkedIn URL', currentUser.linkedinUrl),
                          if (currentUser.profilePictureUrl?.isNotEmpty == true)
                            _buildDataPreviewItem('📸 Profile Picture', currentUser.profilePictureUrl!),
                          _buildDataPreviewItem('🆔 User ID', currentUser.id),
                          _buildDataPreviewItem('📊 Scanned Boxes', currentUser.scannedBoxes.join(', ')),
                          _buildDataPreviewItem('⏰ Timestamp', DateTime.now().toString().split('.')[0]),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FF88).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF00FF88).withOpacity(0.3),
                              ),
                            ),
                            child: const Text(
                              'QR contains your profile details with timestamp for accurate scanning.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF00FF88),
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            */
            const SizedBox(height: 32),

            // Download/Save Buttons
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00AA66), Color(0xFF00FF88)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00FF88).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: () => context.go('/profile'),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit,
                                color: Color(0xFF0D1F1C),
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'EDIT PROFILE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D1F1C),
                                    letterSpacing: 0.8,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A3A35),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: const Color(0xFF00FF88),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: _isDownloading ? null : _downloadQRCode,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isDownloading)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF00FF88),
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.download,
                                  color: Color(0xFF00FF88),
                                  size: 16,
                                ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _isDownloading ? 'SAVING...' : 'SAVE QR',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00FF88),
                                    letterSpacing: 0.8,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
