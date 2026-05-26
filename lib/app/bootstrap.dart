import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/env.dart';
import '../core/logger.dart';
import '../core/platform/url_strategy.dart';
import '../firebase_options.dart';
import 'app.dart';

/// Single entry point. Loads env, initializes Firebase, wires up crash
/// reporting, then mounts the app under a [ProviderScope].
///
/// All bootstrap work runs inside `runZonedGuarded` so any uncaught async
/// error reaches Crashlytics in release builds.
Future<void> bootstrap() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    configureUrlStrategy();
    await Env.load();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Crashlytics doesn't ship on web — guard the wiring accordingly.
    if (!kIsWeb) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

    AppLogger.i('Boot OK — game=${Env.activeGameId}');
    runApp(const ProviderScope(child: NammaBingoApp()));
  }, (error, stack) {
    AppLogger.e('Unhandled error', error: error, stackTrace: stack);
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}
