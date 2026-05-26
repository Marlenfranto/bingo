import 'app_exception.dart';

/// Sum type for fallible operations. Use at repository/service boundaries
/// so callers must handle both branches explicitly.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(AppException error) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  T? get valueOrNull => switch (this) {
        Ok(:final value) => value,
        Err() => null,
      };

  AppException? get errorOrNull => switch (this) {
        Ok() => null,
        Err(:final error) => error,
      };

  R when<R>({
    required R Function(T value) ok,
    required R Function(AppException error) err,
  }) =>
      switch (this) {
        Ok(:final value) => ok(value),
        Err(:final error) => err(error),
      };

  Result<R> map<R>(R Function(T) transform) => switch (this) {
        Ok(:final value) => Ok(transform(value)),
        Err(:final error) => Err(error),
      };
}

final class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

final class Err<T> extends Result<T> {
  final AppException error;
  const Err(this.error);
}
