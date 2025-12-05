enum Environment { development, staging, production }

class AppConfig {
  final Environment environment;
  final String apiBaseUrl;
  final bool enableLogging;
  final bool enableAnalytics;

  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.enableLogging,
    required this.enableAnalytics,
  });

  static const development = AppConfig(
    environment: Environment.development,
    apiBaseUrl: 'https://dev-api.kadmat.ly',
    enableLogging: true,
    enableAnalytics: false,
  );

  static const staging = AppConfig(
    environment: Environment.staging,
    apiBaseUrl: 'https://staging-api.kadmat.ly',
    enableLogging: true,
    enableAnalytics: true,
  );

  static const production = AppConfig(
    environment: Environment.production,
    apiBaseUrl: 'https://api.kadmat.ly',
    enableLogging: false,
    enableAnalytics: true,
  );

  // Current config (change based on build flavor)
  static const current = development;

  bool get isDevelopment => environment == Environment.development;
  bool get isStaging => environment == Environment.staging;
  bool get isProduction => environment == Environment.production;
}
