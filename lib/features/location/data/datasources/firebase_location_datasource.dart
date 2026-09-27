import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/device/local_user_id_store.dart';
import '../models/location_model.dart';
import 'location_datasource.dart';

import 'package:firebase_database/firebase_database.dart';

import '../../../../core/device/android_device_bridge.dart';
import '../../../../core/device/local_user_id_store.dart';

class FirebaseLocationDataSource
    implements LocationDataSource {

  final FirebaseDatabase database;

  String? _deviceUserId;

  FirebaseLocationDataSource({
    required this.database,
  });

  @override
  Future<String> getDeviceUserId() async {
    _deviceUserId ??=
    await LocalUserIdStore.getOrCreate();

    return _deviceUserId!;
  }

  @override
  Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      if (permission == LocationPermission.whileInUse) {
        final second = await Geolocator.requestPermission();
        if (second == LocationPermission.always ||
            second == LocationPermission.whileInUse) {
          return true;
        }
      }
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Future<void> startSharing({String? userName}) async {

    final permissionGranted =
    await requestPermission();

    if (!permissionGranted) {
      throw Exception(
          'Location permission was not granted.'
      );
    }

    final uid =
    await getDeviceUserId();

    await AndroidDeviceBridge.saveDeviceId(uid);

    if (userName != null && userName.trim().isNotEmpty) {
      await AndroidDeviceBridge.saveUserName(userName.trim());
    }

    await AndroidDeviceBridge
        .startLocationService();
  }

  @override
  Future<void> stopSharing() async {

    await AndroidDeviceBridge
        .stopLocationService();
  }

  @override
  Stream<List<LocationModel>> watchLocations() {

    final locationsReference =
    database.ref('locations');

    return locationsReference.onValue.map(
          (event) {

        final value =
            event.snapshot.value;

        if (value == null) {
          return <LocationModel>[];
        }

        final data =
        Map<dynamic, dynamic>.from(
          value as Map,
        );

        return data.entries.map((entry) {

          final uid =
          entry.key.toString();

          final locationMap =
          Map<dynamic, dynamic>.from(
            entry.value as Map,
          );

          return LocationModel.fromMap(
            uid,
            locationMap,
          );

        }).toList();
      },
    );
  }
}