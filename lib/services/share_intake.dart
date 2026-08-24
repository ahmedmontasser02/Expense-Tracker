import 'dart:async';

import 'package:flutter/services.dart';

/// Receives text shared into the app via the Android share sheet
/// (ACTION_SEND text/plain), delivered through a small native channel in
/// MainActivity.
class ShareIntake {
  ShareIntake._();

  static final instance = ShareIntake._();

  static const _method = MethodChannel('app.share_intake');
  static const _events = EventChannel('app.share_intake/stream');

  final _controller = StreamController<String>.broadcast();
  bool _listening = false;

  Stream<String> get stream => _controller.stream;

  /// Text shared before the app was running (cold start).
  Future<String?> consumeInitial() async {
    try {
      final text = await _method.invokeMethod<String>('getInitial');
      if (text != null) {
        await _method.invokeMethod('consume');
      }
      return text;
    } on PlatformException {
      return null;
    }
  }

  void listen() {
    if (_listening) return;
    _listening = true;
    _events.receiveBroadcastStream().listen((data) {
      if (data is String && data.isNotEmpty) {
        _controller.add(data);
      }
    }, onError: (_) {});
  }
}
