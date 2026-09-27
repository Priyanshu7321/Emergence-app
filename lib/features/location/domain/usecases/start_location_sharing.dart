import '../repositories/location_repository.dart';

class StartLocationSharing {
  final LocationRepository repository;

  StartLocationSharing(this.repository);

  Future<void> call({String? userName}) {
    return repository.startSharing(userName: userName);
  }
}