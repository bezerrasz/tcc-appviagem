class ApiConfig {
  ApiConfig._();

  // Override via: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://spinner-convene-fervor.ngrok-free.dev',
  );
}
