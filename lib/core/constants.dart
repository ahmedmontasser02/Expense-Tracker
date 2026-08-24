/// Build-time constants injected via --dart-define.
/// Example: flutter run --dart-define=APP_ENV=dev
const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'prod');

const bool isDevBuild = appEnv == 'dev';

/// GitHub repo used by the in-app update checker.
const String updateRepo = 'ahmedmontasser02/Expense-Tracker';
