import 'url_strategy_io.dart' if (dart.library.html) 'url_strategy_web.dart'
    as impl;

/// Switch Flutter web from `/#/path` (default hash routing) to clean `/path`
/// URLs so direct links like `https://host/scoreboard` resolve correctly.
/// No-op on non-web platforms.
void configureUrlStrategy() => impl.configureUrlStrategy();
