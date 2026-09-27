import '../entities/user_location.dart';

abstract class LocationRepository {
  Future<String> getDeviceUserId();

  Future<bool> requestPermission();

  Future<void> startSharing({String? userName});

  Future<void> stopSharing();

  Stream<UserLocation> watchMyLocation();

  Stream<List<UserLocation>> watchOtherLocations();
}