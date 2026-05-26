/// All recoverable application errors flow through this hierarchy.
/// Anything else escaping to FlutterError handlers is a bug.
sealed class AppException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppException(this.message, {this.cause, this.stackTrace});

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause, super.stackTrace});
}

class AuthException extends AppException {
  const AuthException(super.message, {super.cause, super.stackTrace});
}

class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.cause, super.stackTrace});
}

class ValidationException extends AppException {
  const ValidationException(super.message, {super.cause, super.stackTrace});
}

class PermissionException extends AppException {
  const PermissionException(super.message, {super.cause, super.stackTrace});
}

class ConflictException extends AppException {
  const ConflictException(super.message, {super.cause, super.stackTrace});
}

class UnexpectedException extends AppException {
  const UnexpectedException(super.message, {super.cause, super.stackTrace});
}
