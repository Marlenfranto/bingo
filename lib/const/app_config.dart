import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static int get questionsCount {
    final value = dotenv.env['QUESTIONS_COUNT'];
    return value != null ? int.tryParse(value) ?? 15 : 15;
  }
  
  static bool get allowRepetitivePersonScan {
    final value = dotenv.env['ALLOW_REPETITIVE_PERSON_SCAN'];
    return value?.toLowerCase() == 'true';
  }
  
  static bool get allowSameUserScan {
    final value = dotenv.env['ALLOW_SAME_USER_SCAN'];
    return value?.toLowerCase() == 'true';
  }
}