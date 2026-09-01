/// Central configuration for the app.
/// Keep API keys here — do NOT commit to public repos.
class AppConfig {
  AppConfig._();

  /// Google Gemini API key (loaded dynamically from Firestore system_config/ai, or passed via --dart-define).
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Primary model for AI quiz generation.
  static const String geminiModel = 'gemini-2.5-flash';

  /// Maximum file size the AI generator will accept (20 MB).
  static const int maxUploadBytes = 20 * 1024 * 1024;
}
