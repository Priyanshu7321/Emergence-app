import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/device/android_device_bridge.dart';
import '../../data/datasources/firebase_location_datasource.dart';
import '../../data/datasources/location_datasource.dart';
import '../../data/repositories/location_repository_impl.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/repositories/location_repository.dart';
import '../../domain/usecases/start_location_sharing.dart';
import '../../domain/usecases/stop_location_sharing.dart';
import '../../domain/usecases/watch_other_locations.dart';
import '../state/location_state.dart';

final locationDataSourceProvider =
    Provider<LocationDataSource>((ref) {
  final app = Firebase.app();
  final databaseUrl = app.options.databaseURL;
  if (databaseUrl == null || databaseUrl.isEmpty) {
    throw StateError(
      'Firebase Realtime Database URL is missing. '
      'Enable RTDB in Firebase Console and re-run flutterfire configure.',
    );
  }

  return FirebaseLocationDataSource(
    database: FirebaseDatabase.instanceFor(
      app: app,
      databaseURL: databaseUrl,
    ),
  );
});

final locationRepositoryProvider =
Provider<LocationRepository>((ref) {
  return LocationRepositoryImpl(
    ref.watch(locationDataSourceProvider),
  );
});

final startLocationSharingProvider =
Provider<StartLocationSharing>((ref) {
  return StartLocationSharing(
    ref.watch(locationRepositoryProvider),
  );
});

final stopLocationSharingProvider =
Provider<StopLocationSharing>((ref) {
  return StopLocationSharing(
    ref.watch(locationRepositoryProvider),
  );
});

final watchOtherLocationsProvider =
Provider<WatchOtherLocations>((ref) {
  return WatchOtherLocations(
    ref.watch(locationRepositoryProvider),
  );
});

final locationProvider =
NotifierProvider<LocationNotifier, LocationState>(
  LocationNotifier.new,
);

enum PermissionAskResult {
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
}

class LocationNotifier extends Notifier<LocationState> {
  StreamSubscription<List<UserLocation>>?
  _otherLocationsSubscription;

  StreamSubscription<Position>? _myLocationSubscription;

  StreamSubscription<double>? _compassSubscription;

  late LocationRepository _repository;

  String? _deviceUserId;

  @override
  LocationState build() {
    _repository = ref.read(locationRepositoryProvider);

    ref.onDispose(() {
      _otherLocationsSubscription?.cancel();
      _myLocationSubscription?.cancel();
      _compassSubscription?.cancel();
      AndroidDeviceBridge.disposeCompass();
    });

    _startCompassListening();

    return const LocationState();
  }

  void _startCompassListening() {
    _compassSubscription?.cancel();

    _compassSubscription =
        AndroidDeviceBridge.compassHeadingStream().listen(
              (headingDegrees) {
            state = state.copyWith(myCompassHeading: headingDegrees);
          },
          onError: (_) {},
          cancelOnError: false,
        );
  }

  Future<String> _ensureDeviceUserId() async {
    _deviceUserId ??= await _repository.getDeviceUserId();
    return _deviceUserId!;
  }

  void setUserName(String? name) {
    state = state.copyWith(userName: name);
  }

  Future<void> openAppSettings() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await AndroidDeviceBridge.openAppSettings();
      } catch (_) {}
    } else {
      await Geolocator.openAppSettings();
    }
  }

  Future<void> openLocationSettings() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await AndroidDeviceBridge.openLocationSettings();
      } catch (_) {
        await Geolocator.openLocationSettings();
      }
    } else {
      await Geolocator.openLocationSettings();
    }
  }

  Future<bool> ensureNotificationPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      return await AndroidDeviceBridge.ensureNotificationPermission();
    } catch (_) {
      return true;
    }
  }

  Future<PermissionAskResult> _askLocationPermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return PermissionAskResult.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      return PermissionAskResult.permanentlyDenied;
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        return PermissionAskResult.permanentlyDenied;
      }
      if (permission == LocationPermission.denied) {
        return PermissionAskResult.denied;
      }
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      if (permission == LocationPermission.whileInUse) {
        final second = await Geolocator.requestPermission();
        if (second == LocationPermission.deniedForever) {
          return PermissionAskResult.granted;
        }
      }
    }

    return PermissionAskResult.granted;
  }

  Future<void> prepareMapSession() async {
    if (_otherLocationsSubscription != null) {
      return;
    }

    try {
      await _ensureDeviceUserId();
      _listenToOtherLocations();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> startSharing() async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      permissionDenied: false,
    );

    try {
      await ensureNotificationPermission();

      final askResult = await _askLocationPermissions();

      if (askResult != PermissionAskResult.granted) {
        state = state.copyWith(
          isLoading: false,
          permissionDenied: true,
          error: _messageForAskResult(askResult),
        );
        return;
      }

      final userName = state.userName;

      await ref.read(startLocationSharingProvider).call(
        userName: userName,
      );

      state = state.copyWith(
        isSharing: true,
        isLoading: false,
        error: null,
      );

      _listenToMyLocation();
      _listenToOtherLocations();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  String _messageForAskResult(PermissionAskResult result) {
    switch (result) {
      case PermissionAskResult.serviceDisabled:
        return 'Location services are turned off. Please enable location in device settings.';
      case PermissionAskResult.permanentlyDenied:
        return 'Location permission was permanently denied. Open app settings to enable it.';
      case PermissionAskResult.denied:
        return 'Location permission is required to share your location.';
      case PermissionAskResult.granted:
        return '';
    }
  }

  Future<void> stopSharing() async {
    await _repository.stopSharing();

    await _myLocationSubscription?.cancel();
    await _otherLocationsSubscription?.cancel();

    _myLocationSubscription = null;
    _otherLocationsSubscription = null;

    state = state.copyWith(
      isSharing: false,
      isLoading: false,
      myLocation: null,
      otherLocations: const [],
    );
  }

  void _listenToMyLocation() {
    _myLocationSubscription?.cancel();

    _myLocationSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((position) async {
          final uid = _deviceUserId ?? await _ensureDeviceUserId();
          final userName = state.userName;

          state = state.copyWith(
            myLocation: UserLocation(
              userId: uid,
              latitude: position.latitude,
              longitude: position.longitude,
              accuracy: position.accuracy,
              bearing: position.heading,
              updatedAt:
              DateTime.now().millisecondsSinceEpoch,
              name: userName,
            ),
          );
        });
  }

  void _listenToOtherLocations() {
    _otherLocationsSubscription?.cancel();

    _otherLocationsSubscription =
        ref
            .read(watchOtherLocationsProvider)
            .call()
            .listen((locations) async {
          final myUid = _deviceUserId ?? await _ensureDeviceUserId();

          final others = locations
              .where((location) =>
          location.userId != myUid)
              .toList();

          state = state.copyWith(
            otherLocations: others,
          );
        });
  }
}
