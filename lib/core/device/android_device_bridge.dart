import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidDeviceBridge {
  static const _channel =
  MethodChannel('com.example.emergence/device');

  static const _compassChannel =
  EventChannel('com.example.emergence/compass');

  static StreamSubscription<dynamic>? _compassSubscription;
  static final StreamController<double> _compassController =
      StreamController<double>.broadcast();

  static Future<void> saveDeviceId(String deviceId) async {
    await _channel.invokeMethod(
      'saveDeviceId',
      {'deviceId': deviceId},
    );
  }

  static Future<void> saveUserName(String userName) async {
    await _channel.invokeMethod(
      'saveUserName',
      {'userName': userName},
    );
  }

  static Future<void> startLocationService() async {
    await _channel.invokeMethod(
      'startLocationService',
    );
  }

  static Future<void> stopLocationService() async {
    await _channel.invokeMethod(
      'stopLocationService',
    );
  }

  static Future<bool> ensureNotificationPermission() async {
    final result = await _channel.invokeMethod<bool>(
      'ensureNotificationPermission',
    );
    return result ?? false;
  }

  static Future<void> openAppSettings() async {
    await _channel.invokeMethod('openAppSettings');
  }

  static Future<void> openLocationSettings() async {
    await _channel.invokeMethod('openLocationSettings');
  }

  static Stream<double> compassHeadingStream() {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const Stream<double>.empty();
    }

    if (_compassSubscription == null) {
      _compassSubscription = _compassChannel
          .receiveBroadcastStream()
          .listen(
            (event) {
          if (event is num) {
            _compassController.add(event.toDouble());
          } else if (event is double) {
            _compassController.add(event);
          } else if (event is int) {
            _compassController.add(event.toDouble());
          }
        },
        onError: (_) {},
        cancelOnError: false,
      );
    }

    return _compassController.stream;
  }

  static void disposeCompass() {
    _compassSubscription?.cancel();
    _compassSubscription = null;
  }
}
