import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../providers/location_provider.dart';
import '../state/location_state.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() =>
      _MapScreenState();
}

class _MapScreenState
    extends ConsumerState<MapScreen> {
  MapLibreMapController? _mapController;

  final Map<String, Circle> _userMarkers = {};
  final Map<String, Symbol> _headingSymbols = {};

  bool _imagesRegistered = false;
  static const String _arrowPurple = 'arrow-purple';
  static const String _arrowPink = 'arrow-pink';

  static const LatLng _defaultLocation =
      LatLng(20.5937, 78.9629);

  static const double _streetZoom = 15.5;

  static const String _streetMapStyle =
      'https://tiles.openfreemap.org/styles/liberty';

  bool _centeredOnStart = false;
  bool _autoCenteredOnMyLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final extra = GoRouterState.of(context).extra;
      if (extra is String && extra.isNotEmpty) {
        ref.read(locationProvider.notifier).setUserName(extra);
      }
      () async {
        await Future<void>.delayed(Duration.zero);
        if (!mounted) return;
        ref.read(locationProvider.notifier).prepareMapSession();
        ref.read(locationProvider.notifier).ensureNotificationPermission();
      }();
    });
  }

  Future<Uint8List> _renderArrowPng(Color color, int size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final center = size / 2.0;
    final path = Path()
      ..moveTo(center, size * 0.92)
      ..lineTo(size * 0.88, size * 0.08)
      ..lineTo(center, size * 0.28)
      ..lineTo(size * 0.12, size * 0.08)
      ..close();

    final stroke = Paint()
      ..color = Colors.white
      ..strokeWidth = max(1.0, size * 0.06)
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawPath(path.shift(const Offset(0, 1)), shadow);
    canvas.drawPath(path, stroke);
    canvas.drawPath(path, paint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _registerArrowImages() async {
    final controller = _mapController;
    if (controller == null || _imagesRegistered) return;

    try {
      final purpleBytes = await _renderArrowPng(const Color(0xFF6C63FF), 84);
      final pinkBytes = await _renderArrowPng(const Color(0xFFFF4D6D), 84);

      await controller.addImage(_arrowPurple, purpleBytes);
      await controller.addImage(_arrowPink, pinkBytes);
      _imagesRegistered = true;
    } catch (e) {
      debugPrint('Failed to register arrow images: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(locationProvider, (previous, next) {
      _updateMap(next);
      _updateHeadingSymbols(next);

      if (next.error != null && next.error != previous?.error) {
        if (next.permissionDenied) {
          _showPermissionDialog(next.error!);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next.error!)),
          );
        }
      } else if (next.permissionDenied &&
          previous?.permissionDenied != true) {
        _showPermissionDialog(
          'Location permission is required to share your location.',
        );
      }
    });

    final locationState = ref.watch(locationProvider);

    return Scaffold(
      body: SafeArea(child: Stack(
        children: [
          Positioned.fill(
            child: MapLibreMap(
              initialCameraPosition: const CameraPosition(
                target: _defaultLocation,
                zoom: _streetZoom,
              ),
              styleString: _streetMapStyle,
              myLocationEnabled: false,
              myLocationTrackingMode:
                  MyLocationTrackingMode.none,
              annotationOrder: const [
                AnnotationType.circle,
                AnnotationType.symbol,
              ],
              onMapCreated: (controller) {
                _mapController = controller;
                controller.onCircleTapped.add(_onCircleTapped);
                controller.onSymbolTapped.add(_onSymbolTapped);
              },
              onStyleLoadedCallback: () async {
                await _registerArrowImages();
                _centerMapOnStreetViewAtStart();
                _updateHeadingSymbols(ref.read(locationProvider));
              },
            ),
          ),

          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: _buildTopBar(locationState),
          ),

          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: _buildLocationButton(
              locationState,
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildTopBar(LocationState locationState) {
    final isSharing = locationState.isSharing;
    final userName = locationState.userName;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 20,
            offset: Offset(0, 8),
            color: Colors.black12,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.groups_rounded,
            color: Color(0xFF6C63FF),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locationState.error != null
                      ? 'Sharing failed — see message below'
                      : isSharing
                          ? 'Location sharing active'
                          : 'Location sharing off',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (userName != null && userName.isNotEmpty)
                  Text(
                    'Signed in as $userName',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationButton(
      LocationState locationState,
      ) {
    return SizedBox(
      height: 58,
      child: ElevatedButton.icon(
        onPressed: locationState.isLoading
            ? null
            : () {
          if (locationState.isSharing) {
            ref
                .read(locationProvider.notifier)
                .stopSharing();
          } else {
            ref
                .read(locationProvider.notifier)
                .startSharing();
          }
        },
        icon: Icon(
          locationState.isSharing
              ? Icons.stop_rounded
              : Icons.my_location_rounded,
        ),
        label: Text(
          locationState.isSharing
              ? 'Stop Sharing'
              : 'Start Sharing Location',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
          locationState.isSharing
              ? Colors.redAccent
              : const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  void _showPermissionDialog(String message) {
    final lower = message.toLowerCase();
    final isServiceDisabled =
        lower.contains('location services are turned off') ||
        lower.contains('enable location in device');
    final isPermanent =
        lower.contains('permanently denied') ||
        lower.contains('open app settings');

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permission required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              if (isServiceDisabled) {
                await ref
                    .read(locationProvider.notifier)
                    .openLocationSettings();
              } else if (isPermanent) {
                await ref
                    .read(locationProvider.notifier)
                    .openAppSettings();
              } else {
                ref
                    .read(locationProvider.notifier)
                    .startSharing();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
            child: Text(
              isServiceDisabled
                  ? 'Open Location Settings'
                  : isPermanent
                      ? 'Open App Settings'
                      : 'Grant Permission',
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetail(String userId) {
    if (!mounted) return;

    final locationState = ref.read(locationProvider);
    final allLocations = <String, dynamic>{};

    if (locationState.myLocation != null) {
      allLocations[locationState.myLocation!.userId] =
      locationState.myLocation!;
    }
    for (final loc in locationState.otherLocations) {
      allLocations[loc.userId] = loc;
    }

    final userLocation = allLocations[userId];
    final displayName = userLocation?.name?.toString() ?? userId;
    final readableTime = userLocation?.updatedAtReadable?.toString();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Name: $displayName',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SelectableText(
              'User ID: $userId',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            if (readableTime != null && readableTime.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Last seen: $readableTime',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _onCircleTapped(Circle circle) {
    final userId =
        circle.data?['userId'] as String? ??
            _userMarkers.entries
                .where((e) => e.value.id == circle.id)
                .map((e) => e.key)
                .firstOrNull;

    if (userId == null) return;
    _showUserDetail(userId);
  }

  void _onSymbolTapped(Symbol symbol) {
    final userId = symbol.data?['userId'] as String?;
    if (userId == null) return;
    _showUserDetail(userId);
  }

  Future<void> _updateHeadingSymbols(LocationState state) async {
    final controller = _mapController;
    if (controller == null || !_imagesRegistered) return;

    final allLocations = <String, dynamic>{};
    if (state.myLocation != null) {
      allLocations[state.myLocation!.userId] = state.myLocation!;
    }
    for (final loc in state.otherLocations) {
      allLocations[loc.userId] = loc;
    }

    final activeUserIds = allLocations.keys.toSet();
    for (final userId in _headingSymbols.keys.toList()) {
      if (!activeUserIds.contains(userId)) {
        final symbol = _headingSymbols.remove(userId);
        if (symbol != null) {
          try {
            await controller.removeSymbol(symbol);
          } catch (_) {}
        }
      }
    }

    for (final entry in allLocations.entries) {
      final location = entry.value;
      final isMyLocation = entry.key == state.myLocation?.userId;
      final heading = isMyLocation
          ? state.myCompassHeading
          : ((location.bearing as num?)?.toDouble() ?? 0.0);

      final latLng = LatLng(
        location.latitude,
        location.longitude,
      );

      final iconImage = isMyLocation ? _arrowPurple : _arrowPink;
      final name = location.name?.toString();

      final existing = _headingSymbols[entry.key];
      try {
        if (existing == null) {
          final symbol = await controller.addSymbol(
            SymbolOptions(
              geometry: latLng,
              iconImage: iconImage,
              iconSize: 0.38,
              iconRotate: heading,
              textField: name,
              textSize: 11,
              textAnchor: 'bottom',
              textOffset: const Offset(0, -1.8),
              textColor: isMyLocation ? '#6C63FF' : '#FF4D6D',
              textHaloColor: '#FFFFFF',
              textHaloWidth: 2.2,
            ),
            {'userId': entry.key},
          );
          _headingSymbols[entry.key] = symbol;
        } else {
          await controller.updateSymbol(
            existing,
            SymbolOptions(
              geometry: latLng,
              iconImage: iconImage,
              iconRotate: heading,
              textField: name,
            ),
          );
        }
      } catch (e) {
        debugPrint('Heading symbol error for ${entry.key}: $e');
      }
    }
  }

  Future<void> _updateMap(
      LocationState state,
      ) async {
    final controller = _mapController;

    if (controller == null) return;

    final allLocations = <String, dynamic>{};

    if (state.myLocation != null) {
      allLocations[state.myLocation!.userId] =
      state.myLocation!;
    }

    for (final location in state.otherLocations) {
      allLocations[location.userId] = location;
    }

    final activeUserIds = allLocations.keys.toSet();
    for (final userId in _userMarkers.keys.toList()) {
      if (!activeUserIds.contains(userId)) {
        final circle = _userMarkers.remove(userId);
        if (circle != null) {
          await controller.removeCircle(circle);
        }
      }
    }

    for (final entry in allLocations.entries) {
      final location = entry.value;

      final position = LatLng(
        location.latitude,
        location.longitude,
      );

      final existing =
      _userMarkers[entry.key];

      if (existing == null) {
        final marker = await controller.addCircle(
          CircleOptions(
            geometry: position,
            circleRadius:
                entry.key == state.myLocation?.userId ? 10 : 8,
            circleColor:
                entry.key == state.myLocation?.userId
                    ? '#6C63FF'
                    : '#FF4D6D',
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2,
          ),
          {'userId': entry.key},
        );

        _userMarkers[entry.key] = marker;
      } else {
        await controller.updateCircle(
          existing,
          CircleOptions(
            geometry: position,
          ),
        );
      }
    }

    final myLocation = state.myLocation;

    if (myLocation != null && !_autoCenteredOnMyLocation) {
      _autoCenteredOnMyLocation = true;
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(
            myLocation.latitude,
            myLocation.longitude,
          ),
          _streetZoom,
        ),
      );
    }
  }

  Future<void> _centerMapOnStreetViewAtStart() async {
    if (_centeredOnStart) return;

    final controller = _mapController;
    if (controller == null) return;

    _centeredOnStart = true;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      return;
    }

    Position? position;
    try {
      position = await Geolocator.getLastKnownPosition()
          .timeout(const Duration(milliseconds: 400));
    } catch (_) {}

    try {
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      ).timeout(const Duration(seconds: 2));
    } catch (_) {}

    if (position != null && mounted) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              position!.latitude,
              position.longitude,
            ),
            zoom: _streetZoom,
          ),
        ),
      );
    }
  }
}
