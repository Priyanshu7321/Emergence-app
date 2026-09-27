import '../repositories/location_repository.dart';

class StopLocationSharing {
  final LocationRepository repository;

  StopLocationSharing(this.repository);

  Future<void> call() {
    return repository.stopSharing();
  }
}