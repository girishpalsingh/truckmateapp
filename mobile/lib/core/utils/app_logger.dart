import 'package:logger/logger.dart';

/// Centralized logger for the application.
/// Wraps the [Logger] package to provide a consistent logging interface.
class AppLogger {
  static final Logger _logger = Logger(
    printer: SimplePrinter(
      colors: true,
      printTime: true,
    ),
  );

  /// Log a debug message (Verbose)
  static void d(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log an info message (General info)
  static void i(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log a warning message (Potential issues)
  static void w(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log an error message (Exceptions, failures)
  static void e(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}
