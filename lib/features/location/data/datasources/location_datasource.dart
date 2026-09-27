import '../models/location_model.dart';

abstract class LocationDataSource {
  Future<String> getDeviceUserId();

  Future<bool> requestPermission();

  Future<void> startSharing({String? userName});

  Future<void> stopSharing();

  Stream<List<LocationModel>> watchLocations();
}