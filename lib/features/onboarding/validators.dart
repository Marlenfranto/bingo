/// Tiny pure helpers for the onboarding + profile forms. Pure functions so
/// they're trivially unit-testable without widget infra.
abstract final class Validators {
  Validators._();

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final v = value.trim();
    // Pragmatic regex — RFC-perfect validation isn't needed here.
    final ok = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(v);
    return ok ? null : 'Enter a valid email';
  }

  static String? linkedinUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Enter a full URL (https://…)';
    }
    if (!uri.host.contains('linkedin.com')) {
      return "That doesn't look like a LinkedIn URL";
    }
    return null;
  }
}
