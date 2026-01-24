import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_logger.dart';

/// Observer to log Riverpod provider state changes.
class ProviderLogger extends ProviderObserver {
  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    AppLogger.d('Provider ADDED: ${provider.name ?? provider.runtimeType}');
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    AppLogger.d(
      'Provider UPDATED: ${provider.name ?? provider.runtimeType}\n'
      '  Old: $previousValue\n'
      '  New: $newValue',
    );
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    AppLogger.d('Provider DISPOSED: ${provider.name ?? provider.runtimeType}');
  }
}
