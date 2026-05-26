import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime environment. All `.env` reads go through here so the rest of the
/// app doesn't depend on dotenv directly.
abstract final class Env {
  Env._();

  static Future<void> load() => dotenv.load(fileName: '.env');

  /// The single active game ID. We use a fixed identifier for the
  /// single-active-game model — multi-game support would replace this
  /// with a Firestore query for `games where isActive == true`.
  static String get activeGameId =>
      dotenv.maybeGet('ACTIVE_GAME_ID') ?? 'default-game';

  /// If false, the same person can only fill one slot across the board.
  static bool get allowRepetitivePersonScan =>
      _bool('ALLOW_REPETITIVE_PERSON_SCAN', false);

  /// Envelope signature on the QR payload. Bump (e.g. BINGO_USER_V2) to
  /// invalidate every QR generated before the change.
  static String get qrSignature =>
      dotenv.maybeGet('QR_SIGNATURE') ?? 'BINGO_USER_V1';

  /// Force verbose logging in release builds (for on-site debugging).
  static bool get verboseLogging => _bool('VERBOSE_LOGGING', false);

  static bool _bool(String key, bool fallback) {
    final v = dotenv.maybeGet(key);
    if (v == null) return fallback;
    return v.toLowerCase() == 'true';
  }
}
