import 'dart:async';
import 'dart:math' as math;
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';

class LocationManager {
  static final LocationManager _instance = LocationManager._internal();
  factory LocationManager() => _instance;
  LocationManager._internal();

  final Location _location = Location();
  LatLng? _currentLocation;
  StreamController<LatLng> _locationController = StreamController<LatLng>.broadcast();
  Timer? _locationUpdateTimer;
  bool _isInitialized = false;

  // Getter for current location
  LatLng? get currentLocation => _currentLocation;

  // Getter for location stream
  Stream<LatLng> get locationStream => _locationController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if location service is enabled
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          throw Exception('Location service not enabled');
        }
      }

      // Check location permission
      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          throw Exception('Location permission not granted');
        }
      }

      // Start location updates
      await _startLocationUpdates();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing location manager: $e');
      rethrow;
    }
  }

  Future<void> _startLocationUpdates() async {
    try {
      // Set location settings
      await _location.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 5000, // Update every 5 seconds
      );

      // Get initial location
      final locationData = await _location.getLocation();
      _updateLocation(locationData);

      // Listen to location changes
      _location.onLocationChanged.listen((LocationData locationData) {
        _updateLocation(locationData);
      });

      // Start periodic updates as backup
      _locationUpdateTimer?.cancel();
      _locationUpdateTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
        try {
          final locationData = await _location.getLocation();
          _updateLocation(locationData);
        } catch (e) {
          debugPrint('Error updating location: $e');
        }
      });
    } catch (e) {
      debugPrint('Error starting location updates: $e');
    }
  }

  void _updateLocation(LocationData locationData) {
    if (locationData.latitude != null && locationData.longitude != null) {
      _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
      _locationController.add(_currentLocation!);
    }
  }

  void dispose() {
    _locationUpdateTimer?.cancel();
    _locationController.close();
    _isInitialized = false;
  }

  // Helper method to get current location
  Future<LatLng?> getCurrentLocation() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _currentLocation;
  }

  // Helper method to calculate distance from current location
  Future<double> getDistanceFromCurrent(LatLng destination) async {
    if (_currentLocation == null) {
      await getCurrentLocation();
    }
    if (_currentLocation == null) {
      throw Exception('Could not get current location');
    }

    return _calculateDistance(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      destination.latitude,
      destination.longitude,
    );
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Radius of Earth in kilometers
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    double c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }
} 