import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../pages/Orders.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:ecub_delivery/services/location_manager.dart';

class RideService {
  static const BASE_PRICE_PER_KM = 25.0;
  static const CONVENIENCE_FEE_PERCENTAGE = 0.03;
  static const CANCELLATION_FEE = 1.0;
  static const SIXSEATER_DISCOUNT_PER_KM = 3.0;
  static const ORDER_EXPIRY_MINUTES = 5;
  
  final LocationManager _locationManager = LocationManager();

  // Calculate price based on distance and vehicle type
  static double calculatePrice(double distance, String vehicleType) {
    double basePrice = distance * BASE_PRICE_PER_KM;
    if (vehicleType == '6seater') {
      basePrice -= distance * SIXSEATER_DISCOUNT_PER_KM;
    }
    double convenienceFee = basePrice * CONVENIENCE_FEE_PERCENTAGE;
    return basePrice + convenienceFee;
  }

  // Generate 6-digit OTP
  static String generateOTP() {
    Random random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Create new ride order
  Future<String> createRideOrder(RideOrder order) async {
    try {
      final docRef = await FirebaseFirestore.instance
          .collection('ride_orders')
          .add(order.toMap());
      
      // Start timer for 5-minute expiration
      Future.delayed(Duration(minutes: ORDER_EXPIRY_MINUTES), () async {
        final doc = await docRef.get();
        if (doc.exists && doc.data()?['status'] == 'pending') {
          await docRef.update({
            'status': 'expired',
            'expiry_time': FieldValue.serverTimestamp(),
          });
        }
      });

      return docRef.id;
    } catch (e) {
      print('Error creating ride order: $e');
      rethrow;
    }
  }

  // Check if a driver's route is within 2km of passenger's pickup
  Future<bool> isWithinRange(
    LatLng driverStart,
    LatLng driverEnd,
    LatLng passengerLocation,
  ) async {
    try {
      final points = await getRoutePoints(driverStart, driverEnd);
      
      for (LatLng point in points) {
        // Use LocationManager's distance calculation
        double distance = await _locationManager.getDistanceFromCurrent(point);
        if (distance <= 2.0) return true;
      }
      
      return false;
    } catch (e) {
      print('Error checking range: $e');
      return false;
    }
  }

  // Get route points from Google Maps API
  Future<List<LatLng>> getRoutePoints(LatLng start, LatLng end) async {
    final apiKey = 'AIzaSyDBRvts55sYzQ0hcPcF0qp6ApnwW-hHmYo';
    final polylinePoints = PolylinePoints();
    
    try {
      final result = await polylinePoints.getRouteBetweenCoordinates(
        apiKey,
        PointLatLng(start.latitude, start.longitude),
        PointLatLng(end.latitude, end.longitude),
      );

      if (result.points.isNotEmpty) {
        return result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
      }
    } catch (e) {
      print('Error getting route points: $e');
    }
    return [];
  }

  // Calculate distance between two points
  Future<double> calculateDistance(LatLng point1, LatLng point2) async {
    final apiKey = 'AIzaSyDBRvts55sYzQ0hcPcF0qp6ApnwW-hHmYo';
    final url = 'https://maps.googleapis.com/maps/api/distancematrix/json'
        '?origins=${point1.latitude},${point1.longitude}'
        '&destinations=${point2.latitude},${point2.longitude}'
        '&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    if (data['status'] == 'OK') {
      final distance = data['rows'][0]['elements'][0]['distance']['value'] / 1000;
      return distance;
    }
    return double.infinity;
  }

  // Add method to check if ride request expired
  Future<void> checkAndExpireRequest(String orderId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('ride_orders')
          .doc(orderId)
          .get();

      if (!doc.exists) return;

      final data = doc.data()!;
      final requestTime = (data['request_time'] as Timestamp).toDate();
      final now = DateTime.now();

      if (data['status'] == 'pending' && 
          now.difference(requestTime).inMinutes >= 3) {
        await doc.reference.update({
          'status': 'expired',
          'expiry_time': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error checking ride expiry: $e');
    }
  }

  // Add method to accept ride
  Future<bool> acceptRide(String orderId, String riderId) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('ride_orders')
          .doc(orderId);
      
      bool success = false;
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        
        if (!doc.exists) throw 'Order not found';
        if (doc.data()!['status'] != 'pending') throw 'Order no longer available';
        
        transaction.update(docRef, {
          'status': 'accepted',
          'rider_id': riderId,
          'accept_time': FieldValue.serverTimestamp(),
        });
        
        success = true;
      });
      
      return success;
    } catch (e) {
      print('Error accepting ride: $e');
      return false;
    }
  }

  // Add method to start ride
  Future<bool> startRide(String orderId, String otp) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('ride_orders')
          .doc(orderId)
          .get();

      if (!doc.exists) return false;
      if (doc.data()!['otp'] != otp) return false;

      await doc.reference.update({
        'status': 'in_transit',
        'start_time': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error starting ride: $e');
      return false;
    }
  }

  // Add method to complete ride
  Future<bool> completeRide(String orderId) async {
    try {
      await FirebaseFirestore.instance
          .collection('ride_orders')
          .doc(orderId)
          .update({
        'status': 'completed',
        'end_time': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error completing ride: $e');
      return false;
    }
  }

  // Add retry booking method
  Future<bool> retryBooking(String orderId) async {
    try {
      await FirebaseFirestore.instance
          .collection('ride_orders')
          .doc(orderId)
          .update({
        'status': 'pending',
        'request_time': FieldValue.serverTimestamp(),
      });

      // Start new expiry timer
      Future.delayed(Duration(minutes: ORDER_EXPIRY_MINUTES), () async {
        final doc = await FirebaseFirestore.instance
            .collection('ride_orders')
            .doc(orderId)
            .get();
            
        if (doc.exists && doc.data()?['status'] == 'pending') {
          await doc.reference.update({
            'status': 'expired',
            'expiry_time': FieldValue.serverTimestamp(),
          });
        }
      });

      return true;
    } catch (e) {
      print('Error retrying booking: $e');
      return false;
    }
  }
} 