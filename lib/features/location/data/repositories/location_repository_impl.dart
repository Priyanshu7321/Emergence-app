import '../../domain/entities/user_location.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/location_datasource.dart';

class LocationRepositoryImpl implements LocationRepository {
  final LocationDataSource dataSource;

  LocationRepositoryImpl(this.dataSource);

  @override
  Future<String> getDeviceUserId() {
    return dataSource.getDeviceUserId();
  }

  @override
  Future<bool> requestPermission() {
    return dataSource.requestPermission();
  }

  @override
  Future<void> startSharing({String? userName}) {
    return dataSource.startSharing(userName: userName);
  }

  @override
  Future<void> stopSharing() {
    return dataSource.stopSharing();
  }

  @override
  Stream<List<UserLocation>> watchOtherLocations() {
    return dataSource.watchLocations();
  }

  @override
  Stream<UserLocation> watchMyLocation() {
    throw UnimplementedError();
  }


}