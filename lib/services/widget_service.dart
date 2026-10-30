import 'dart:convert';

import 'package:flutter/services.dart';

/// Android home screen widgets. The app pushes what the widgets show; tapping
/// a widget opens the app with a `plotshot://` link describing what to do.
abstract class WidgetService {
  /// Replaces the widget data with [data] and redraws every widget.
  Future<void> update(Map<String, Object?> data);

  /// The widget tap that launched the app, if any. Returned once.
  Future<Uri?> takeLaunch();

  /// Calls [onLaunch] for widget taps while the app is already running.
  void listen(void Function(Uri uri) onLaunch);
}

class PlatformWidgetService implements WidgetService {
  static const _channel = MethodChannel('com.plotshot.app/widgets');

  @override
  Future<void> update(Map<String, Object?> data) =>
      _channel.invokeMethod('update', jsonEncode(data));

  @override
  Future<Uri?> takeLaunch() async {
    final link = await _channel.invokeMethod<String>('takeLaunch');
    return link == null ? null : Uri.tryParse(link);
  }

  @override
  void listen(void Function(Uri uri) onLaunch) {
    _channel.setMethodCallHandler((call) async {
      final link = call.arguments;
      if (call.method != 'launch' || link is! String) return;
      final uri = Uri.tryParse(link);
      if (uri != null) onLaunch(uri);
    });
  }
}

class NoopWidgetService implements WidgetService {
  const NoopWidgetService();
  @override
  Future<void> update(Map<String, Object?> data) async {}
  @override
  Future<Uri?> takeLaunch() async => null;
  @override
  void listen(void Function(Uri uri) onLaunch) {}
}
