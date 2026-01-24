import 'package:flutter/material.dart';
import 'app_logger.dart';

/// Observer to log Navigation events.
class NavigationLogger extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    AppLogger.i('Navigation PUSH: ${_getRouteName(route)}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    AppLogger.i('Navigation POP: ${_getRouteName(route)}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    AppLogger.i(
        'Navigation REPLACE: ${_getRouteName(oldRoute)} -> ${_getRouteName(newRoute)}');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    AppLogger.i('Navigation REMOVE: ${_getRouteName(route)}');
  }

  String _getRouteName(Route<dynamic>? route) {
    if (route == null) return 'null';
    if (route.settings.name != null) return route.settings.name!;
    // Return the runtime type if name is missing (e.g., DialogRoute, ModalBottomSheetRoute)
    return '${route.runtimeType} (Unnamed)';
  }
}
