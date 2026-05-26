import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import 'env.dart';

/// Thin wrapper around `logger` with sensible defaults. Routes to console
/// in debug; quiet in release unless [Env.verboseLogging] is set.
abstract final class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: false,
    ),
    level: kReleaseMode && !Env.verboseLogging ? Level.warning : Level.debug,
  );

  static void d(Object? message) => _logger.d(message);
  static void i(Object? message) => _logger.i(message);
  static void w(Object? message) => _logger.w(message);
  static void e(Object? message, {Object? error, StackTrace? stackTrace}) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}
