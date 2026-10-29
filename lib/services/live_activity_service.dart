import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Drives the iOS Live Activity through a small native channel (see
/// ios/Runner/AppDelegate.swift). Local updates only, no push, so it works
/// with a free Apple developer account. No-ops off iOS or when the user has
/// disabled Live Activities.
class LiveActivityService {
  static const _channel = MethodChannel('splits/live_activity');

  bool _ready = false;
  bool _active = false;

  Future<void> init() async {
    if (!Platform.isIOS) return;
    try {
      _ready = await _channel.invokeMethod<bool>('isEnabled') ?? false;
    } catch (e) {
      debugPrint('Live Activities disabled: $e');
    }
  }

  Future<void> startOrUpdate(Map<String, dynamic> data) async {
    if (!_ready) return;
    try {
      await _channel.invokeMethod('startOrUpdate', data);
      _active = true;
    } catch (e) {
      debugPrint('Live Activity error: $e');
    }
  }

  Future<void> end() async {
    if (!_ready || !_active) return;
    _active = false;
    try {
      await _channel.invokeMethod('end');
    } catch (e) {
      debugPrint('Live Activity error: $e');
    }
  }
}
