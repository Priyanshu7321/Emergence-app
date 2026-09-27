import '../../domain/entities/user_location.dart';

class LocationModel extends UserLocation {
  const LocationModel({
    required super.userId,
    required super.latitude,
    required super.longitude,
    required super.accuracy,
    super.bearing = 0.0,
    required super.updatedAt,
    super.name,
    super.updatedAtReadable,
  });

  factory LocationModel.fromMap(
      String userId,
      Map<dynamic, dynamic> map,
      ) {
    return LocationModel(
      userId: userId,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0,
      bearing: (map['bearing'] as num?)?.toDouble() ?? 0,
      updatedAt: (map['updatedAt'] as num?)?.toInt() ?? 0,
      name: map['name'] as String?,
      updatedAtReadable: map['updatedAtReadable'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'bearing': bearing,
      'updatedAt': updatedAt,
      if (name != null) 'name': name,
      if (updatedAtReadable != null) 'updatedAtReadable': updatedAtReadable,
    };
  }
}