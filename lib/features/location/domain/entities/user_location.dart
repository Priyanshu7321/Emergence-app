class UserLocation {
  final String userId;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double bearing;
  final int updatedAt;
  final String? name;
  final String? updatedAtReadable;

  const UserLocation({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.bearing = 0.0,
    required this.updatedAt,
    this.name,
    this.updatedAtReadable,
  });
}