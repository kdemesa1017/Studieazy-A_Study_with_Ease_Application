/// Central configuration for the app.
/// Keep API keys here — do NOT commit to public repos.
class AppConfig {
  AppConfig._();

  /// Google Gemini API key (free tier).
  /// Can be passed securely at build time via: flutter build web --dart-define=GEMINI_API_KEY=your_key
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: "AQ.Ab8RN6J0ChBCTMqgrLKqih4PHHGLjbxLQdCt2OAh2NA84i7KhQ",
  );

  /// Primary model for AI quiz generation.
  static const String geminiModel = 'gemini-flash-latest';

  /// Maximum file size the AI generator will accept (20 MB).
  static const int maxUploadBytes = 20 * 1024 * 1024;
}
