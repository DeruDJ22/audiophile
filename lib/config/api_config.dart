import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized API configuration loader.
/// Reads keys from .env file — never hardcode API credentials.
class ApiConfig {
  static String get jamendoClientId =>
      dotenv.env['JAMENDO_CLIENT_ID'] ?? '';

  static bool get hasJamendoKey =>
      jamendoClientId.isNotEmpty && jamendoClientId != 'your_jamendo_client_id_here';
}
