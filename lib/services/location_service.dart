import 'dart:async';
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ecub_delivery/pages/Orders.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Timer? _locationUpdateTimer;
  final Location _location = Location();
  bool _isUpdatingLocation = false;
  RideOrder? currentOrder;

  void startLocationUpdates(RideOrder order) async {
    currentOrder = order;
    await _setupLocationUpdates();
  }

  void stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    _isUpdatingLocation = false;
    currentOrder = null;
  }

  Future<void> _setupLocationUpdates() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return;
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }

      _locationUpdateTimer = Timer.periodic(
        Duration(seconds: 20),
        (timer) async {
          if (!_isUpdatingLocation && currentOrder != null) {
            await _updateLocation();
          }
        },
      );
    } catch (e) {
      debugPrint('Error setting up location updates: $e');
    }
  }

  Future<void> _updateLocation() async {
    if (_isUpdatingLocation) return;
    _isUpdatingLocation = true;

    try {
      final locationData = await _location.getLocation();
      
      if (currentOrder == null) return;

      await FirebaseFirestore.instance
          .collection('ride_orders')
          .doc(currentOrder!.orderId)
          .update({
        'current_location': GeoPoint(
          locationData.latitude!,
          locationData.longitude!,
        ),
        'last_location_update': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      debugPrint('Error updating location: $e');
    } finally {
      _isUpdatingLocation = false;
    }
  }
} 