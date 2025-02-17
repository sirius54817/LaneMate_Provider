import 'package:ecub_delivery/klu_page/Orders.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class KLURideService {
  static int calculatePrice(double distance, String vehicleType) {
    // Price per kilometer for KLU rides
    const double pricePerKm = 1.5;
    
    // Calculate base price
    double totalPrice = distance * pricePerKm;
    
    // Add vehicle type premium for 6-seater
    if (vehicleType.toLowerCase() == '6seater') {
      totalPrice += 5.0; // Small premium for 6-seater
    }
    
    // Round to nearest rupee
    return totalPrice.round();
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