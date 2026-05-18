import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';
import '../widgets/bingo_grid.dart';
import '../const/questions.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentQuestionIndex = 0;
  bool _showingQuestionMode = false;

  @override
  void initState() {
    super.initState();
    // Initialize current question index based on completed boxes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bingoBoxes = ref.read(bingoBoxesProvider.notifier);
      _currentQuestionIndex = bingoBoxes.completedCount;
    });
  }

  void _showPersonDetails(BuildContext context, int boxId) {
    final bingoBoxes = ref.read(bingoBoxesProvider);
    final box = bingoBoxes.firstWhere((box) => box.id == boxId);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1F1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Profile section
            Row(
              children: [
                // Profile image
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
                    child: box.scannedByProfilePicture != null
                        ? Image.network(
                            box.scannedByProfilePicture!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildFallbackAvatar(box.scannedByName),
                          )
                        : _buildFallbackAvatar(box.scannedByName),
                  ),
                ),
                const SizedBox(width: 16),

                // Name and title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        box.scannedByName ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF88).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF00FF88),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'Connected',
                          style: TextStyle(
                            color: Color(0xFF00FF88),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Question answered section
            if (box.questionAnswered != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3A35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00FF88).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.quiz,
                          color: Color(0xFF00FF88),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Question Answered:',
                          style: TextStyle(
                            color: Color(0xFF00FF88),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getQuestionText(box.questionAnswered!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Connect button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed:
                    box.scannedByLinkedIn != null &&
                        box.scannedByLinkedIn!.isNotEmpty
                    ? () => _launchLinkedIn(box.scannedByLinkedIn!)
                    : null,
                icon: const Icon(Icons.link, size: 20),
                label: Text(
                  box.scannedByLinkedIn != null &&
                          box.scannedByLinkedIn!.isNotEmpty
                      ? 'Connect on LinkedIn'
                      : 'No LinkedIn URL available',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      box.scannedByLinkedIn != null &&
                          box.scannedByLinkedIn!.isNotEmpty
                      ? const Color(0xFF0077B5)
                      : Colors.grey,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(String? name) {
    final initial = name?.isNotEmpty == true ? name![0].toUpperCase() : '?';
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A3A35),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00FF88),
          ),
        ),
      ),
    );
  }

  String _getQuestionText(String questionAnswered) {
    // The questionAnswered field already contains the full question text
    return questionAnswered.isNotEmpty
        ? questionAnswered
        : 'Question not found';
  }

  Future<void> _launchLinkedIn(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open LinkedIn: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showUnfilledQuestions() {
    final bingoBoxes = ref.read(bingoBoxesProvider);
    final currentUser = ref.read(currentUserProvider);
    final completedBoxes = bingoBoxes.where((box) => box.isSelected).length;

    // Check if all questions are completed
    if (completedBoxes >= 15) {
      _showCompletionDialog();
      return;
    }

    // Get unfilled questions by checking which box IDs are not scanned
    final unfilledQuestions = <Map<String, dynamic>>[];
    for (int i = 0; i < Questions.flutterEventQuestions.length; i++) {
      final boxId = i + 1; // Box IDs start from 1
      final isBoxFilled = currentUser?.scannedBoxes.contains(boxId) ?? false;

      if (!isBoxFilled) {
        unfilledQuestions.add({
          'index': i,
          'boxId': boxId,
          'question': Questions.flutterEventQuestions[i],
        });
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF0D1F1C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF00FF88), width: 2),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      const Text(
                        'Select Question to Fill',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Unfilled questions list
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: unfilledQuestions.length,
                    itemBuilder: (context, index) {
                      final questionData = unfilledQuestions[index];
                      final questionIndex = questionData['index'];
                      final question = questionData['question'];

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A3A35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF00FF88).withOpacity(0.3),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FF88).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${questionIndex + 1}',
                              style: const TextStyle(
                                color: Color(0xFF00FF88),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          title: Text(
                            question,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.3,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF00FF88),
                            size: 24,
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            final boxId = questionData['boxId'];
                            _showSelectedQuestion(
                              questionIndex,
                              question,
                              boxId,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSelectedQuestion(int questionIndex, String question, int boxId) {
    setState(() {
      _showingQuestionMode = true;
      _currentQuestionIndex = questionIndex;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF0D1F1C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF00FF88), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Question header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF88),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Question ${questionIndex + 1}/15',
                        style: const TextStyle(
                          color: Color(0xFF0D1F1C),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showingQuestionMode = false;
                        });
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.close, color: Colors.white),
                      iconSize: 20,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Question text
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3A35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00FF88).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    question,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _showingQuestionMode = false;
                          });
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF00FF88)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF00FF88),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          // Navigate to camera to scan for this question
                          context.go('/camera', extra: {
                            'boxId': boxId,
                            'questionIndex': questionIndex,
                            'questionText': question,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FF88),
                          foregroundColor: const Color(0xFF0D1F1C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Find & Scan',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      setState(() {
        _showingQuestionMode = false;
      });
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF0D1F1C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF00FF88), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.celebration,
                  color: Color(0xFF00FF88),
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Congratulations!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You have completed all 15 networking questions!',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    foregroundColor: const Color(0xFF0D1F1C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Awesome!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final bingoBoxes = ref.watch(bingoBoxesProvider);
    final totalBoxes = 15;
    final scannedCount = currentUser?.scannedBoxes.length ?? 0;
    final remainingForBingo = 15 - scannedCount; // All 15 needed for bingo

    // Update current question index based on completed boxes
    final completedBoxes = bingoBoxes.where((box) => box.isSelected).length;
    if (_currentQuestionIndex != completedBoxes && !_showingQuestionMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _currentQuestionIndex = completedBoxes;
        });
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1F1C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1F1C),
        elevation: 0,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/bingo.png',
              height: 32,
            ),
            const Text(
              'Namma Bingo',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: currentUser?.profilePictureUrl != null
                ? ClipOval(
                    child: Image.network(
                      currentUser!.profilePictureUrl!,
                      fit: BoxFit.cover,
                      width: 40,
                      height: 40,
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF1A3A35),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            currentUser.name.isNotEmpty
                                ? currentUser.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00FF88),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A3A35),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        currentUser?.name.isNotEmpty == true
                            ? currentUser!.name[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00FF88),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.settings, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Section
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bingo progress text
                if (remainingForBingo > 0)
                  Text(
                    '$remainingForBingo more to go bingo!',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF00FF88),
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                const SizedBox(height: 16),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: scannedCount / totalBoxes,
                    backgroundColor: const Color(0xFF1A3A35),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF00FF88),
                    ),
                    minHeight: 12,
                  ),
                ),
              ],
            ),
          ),

          // Bingo Grid
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: BingoGrid(
                boxes: bingoBoxes,
                onBoxTap: currentUser != null
                    ? (boxId) {
                        final box = bingoBoxes.firstWhere(
                          (box) => box.id == boxId,
                        );

                        if (box.scannedBy != null &&
                            currentUser.scannedBoxes.contains(boxId)) {
                          // Show person details for filled slots
                          _showPersonDetails(context, boxId);
                        } else if (!currentUser.scannedBoxes.contains(boxId)) {
                          // Navigate to camera for empty slots
                          context.go('/camera', extra: {'boxId': boxId});
                        }
                      }
                    : null,
                currentUser: currentUser,
              ),
            ),
          ),

          // Helper text
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Tap filled slots to view details and connect on LinkedIn',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ),

          // Scan Button
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: currentUser != null
                    ? _showUnfilledQuestions
                    : () => context.go('/profile'),
                icon: const Icon(Icons.qr_code_scanner, size: 28),
                label: Text(
                  _currentQuestionIndex >= 15
                      ? 'All Questions Complete!'
                      : 'Scan to Connect',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentQuestionIndex >= 15
                      ? const Color(0xFF00AA66)
                      : const Color(0xFF00FF88),
                  foregroundColor: const Color(0xFF0D1F1C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
