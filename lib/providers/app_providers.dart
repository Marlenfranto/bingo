import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../const/questions.dart';
import '../const/app_config.dart';
import 'dart:convert';

// Current user provider
final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, User?>((ref) {
  return CurrentUserNotifier();
});

class CurrentUserNotifier extends StateNotifier<User?> {
  CurrentUserNotifier() : super(null) {
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        final userData = jsonDecode(userJson);
        // Validate the data before creating user
        if (userData is Map<String, dynamic> && 
            userData['name'] is String && 
            userData['linkedinUrl'] is String) {
          state = User.fromJson(userData);
        } else {
          // Clear corrupted data
          await prefs.remove('current_user');
        }
      }
    } catch (e) {
      // Clear corrupted data on error
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user');
    }
  }

  Future<void> updateUser(User user) async {
    state = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', jsonEncode(user.toJson()));
  }

  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    state = null;
  }

  Future<void> addScannedBox(int boxId) async {
    if (state != null) {
      final updatedUser = state!.copyWith(
        scannedBoxes: {...state!.scannedBoxes, boxId},
      );
      await updateUser(updatedUser);
    }
  }
}

// Bingo boxes state provider
final bingoBoxesProvider = StateNotifierProvider<BingoBoxesNotifier, List<BingoBox>>((ref) {
  return BingoBoxesNotifier();
});

class BingoBoxesNotifier extends StateNotifier<List<BingoBox>> {
  BingoBoxesNotifier() : super(_generateInitialBoxes()) {
    _loadBoxes();
  }

  static List<BingoBox> _generateInitialBoxes() {
    return List.generate(AppConfig.questionsCount, (index) => BingoBox(id: index + 1));
  }

  Future<void> _loadBoxes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final boxesJson = prefs.getString('bingo_boxes');
      if (boxesJson != null) {
        final List<dynamic> boxesData = jsonDecode(boxesJson);
        final List<BingoBox> boxes = boxesData.map((boxData) {
          return BingoBox(
            id: boxData['id'] ?? 0,
            isSelected: boxData['isSelected'] ?? false,
            scannedBy: boxData['scannedBy'],
            scannedByName: boxData['scannedByName'],
            scannedByProfilePicture: boxData['scannedByProfilePicture'],
            scannedByLinkedIn: boxData['scannedByLinkedIn'],
            questionAnswered: boxData['questionAnswered'],
            scannedAt: boxData['scannedAt'] != null 
                ? DateTime.tryParse(boxData['scannedAt'])
                : null,
          );
        }).toList();
        
        // Ensure we have all required boxes
        if (boxes.length == AppConfig.questionsCount) {
          state = boxes;
        } else {
          state = _generateInitialBoxes();
          await _saveBoxes();
        }
      } else {
        state = _generateInitialBoxes();
        await _saveBoxes();
      }
    } catch (e) {
      // If there's an error loading, start fresh
      state = _generateInitialBoxes();
      await _saveBoxes();
    }
  }

  Future<void> _saveBoxes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final boxesData = state.map((box) => {
        'id': box.id,
        'isSelected': box.isSelected,
        'scannedBy': box.scannedBy,
        'scannedByName': box.scannedByName,
        'scannedByProfilePicture': box.scannedByProfilePicture,
        'scannedByLinkedIn': box.scannedByLinkedIn,
        'questionAnswered': box.questionAnswered,
        'scannedAt': box.scannedAt?.toIso8601String(),
      }).toList();
      await prefs.setString('bingo_boxes', jsonEncode(boxesData));
    } catch (e) {
      // Handle save error silently
      debugPrint('Error saving boxes: $e');
    }
  }

  void selectBox(int boxId, String scannedBy, String scannedByName, String? profilePictureUrl, {String? linkedInUrl, String? questionAnswered}) {
    state = state.map((box) {
      if (box.id == boxId) {
        return box.copyWith(
          isSelected: true,
          scannedBy: scannedBy,
          scannedByName: scannedByName,
          scannedByProfilePicture: profilePictureUrl,
          scannedByLinkedIn: linkedInUrl,
          questionAnswered: questionAnswered,
          scannedAt: DateTime.now(),
        );
      }
      return box;
    }).toList();
    
    // Save to local storage
    _saveBoxes();
  }

  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bingo_boxes');
    state = _generateInitialBoxes();
    await _saveBoxes();
  }

  bool isBoxScanned(int boxId) {
    return state.firstWhere((box) => box.id == boxId).isSelected;
  }

  int get completedCount {
    return state.where((box) => box.isSelected).length;
  }

  String getCurrentQuestion() {
    final completed = completedCount;
    if (completed < Questions.flutterEventQuestions.length) {
      return Questions.flutterEventQuestions[completed];
    }
    return "All questions completed!";
  }

  List<String> getCompletedQuestions() {
    final completed = completedCount;
    return Questions.flutterEventQuestions.take(completed).toList();
  }
}

// Scan status provider
final scanStatusProvider = StateProvider<String?>((ref) => null);