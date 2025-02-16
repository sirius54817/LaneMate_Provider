import 'package:ecub_delivery/klu_page/Orders.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class KLURideService {
  static int calculatePrice(double distance, String vehicleType) {
    // Base price for the first kilometer
    int basePrice = 50;
    
    // Price per additional kilometer
    double pricePerKm = vehicleType.toLowerCase() == '6seater' ? 15.0 : 12.0;
    
    // Calculate total price
    int totalPrice = basePrice + (distance * pricePerKm).round();
    
    // Add vehicle type premium
    if (vehicleType.toLowerCase() == '6seater') {
      totalPrice += 20; // Additional premium for 6-seater
    }
    
    // Round to nearest 10
    return ((totalPrice + 5) ~/ 10) * 10;
  }

  static String generateOTP() {
    // Generate a 6-digit OTP
    Random random = Random();
    String otp = '';
    
    for (int i = 0; i < 6; i++) {
      otp += random.nextInt(10).toString();
    }
    
    return otp;
  }

  Future<String> createRideOrder(RideOrder order) async {
    final orderRef = await FirebaseFirestore.instance
        .collection('klu_ride_orders')
        .add(order.toMap());
    return orderRef.id;
  }
} 