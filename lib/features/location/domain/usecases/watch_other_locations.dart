import '../entities/user_location.dart';
import '../repositories/location_repository.dart';

class WatchOtherLocations {
  final LocationRepository repository;

  WatchOtherLocations(this.repository);

  Stream<List<UserLocation>> call() {
    return repository.watchOtherLocations();
  }
}