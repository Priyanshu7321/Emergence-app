import '../../domain/entities/user_location.dart';

class LocationState {
  final bool isSharing;
  final bool isLoading;
  final bool permissionDenied;
  final UserLocation? myLocation;
  final List<UserLocation> otherLocations;
  final String? error;
  final String? userName;
  final double myCompassHeading;

  const LocationState({
    this.isSharing = false,
    this.isLoading = false,
    this.permissionDenied = false,
    this.myLocation,
    this.otherLocations = const [],
    this.error,
    this.userName,
    this.myCompassHeading = 0.0,
  });

  LocationState copyWith({
    bool? isSharing,
    bool? isLoading,
    bool? permissionDenied,
    UserLocation? myLocation,
    List<UserLocation>? otherLocations,
    String? error,
    String? userName,
    double? myCompassHeading,
  }) {
    return LocationState(
      isSharing: isSharing ?? this.isSharing,
      isLoading: isLoading ?? this.isLoading,
      permissionDenied:
      permissionDenied ?? this.permissionDenied,
      myLocation: myLocation ?? this.myLocation,
      otherLocations:
      otherLocations ?? this.otherLocations,
      error: error,
      userName: userName ?? this.userName,
      myCompassHeading: myCompassHeading ?? this.myCompassHeading,
    );
  }
}