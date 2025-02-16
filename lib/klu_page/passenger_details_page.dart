import 'package:flutter/material.dart';
import '../services/klu_ride_service.dart';
import '../klu_page/Orders.dart';
import '../klu_page/ride_status.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PassengerDetailsPage extends StatefulWidget {
  final Set<String> selectedSeats;
  final String startAddress;
  final String destinationAddress;
  final LatLng startPoint;
  final LatLng destination;
  final String distance;
  final String vehicleType;

  const PassengerDetailsPage({
    Key? key,
    required this.selectedSeats,
    required this.startAddress,
    required this.destinationAddress,
    required this.startPoint,
    required this.destination,
    required this.distance,
    required this.vehicleType,
  }) : super(key: key);

  @override
  State<PassengerDetailsPage> createState() => _PassengerDetailsklu_pagetate();
}

class _PassengerDetailsklu_pagetate extends State<PassengerDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, Map<String, String>> passengerDetails = {};
  final KLURideService _rideService = KLURideService();
  bool _isCreatingOrder = false;

  @override
  void initState() {
    super.initState();
    // Initialize the passenger details map for each seat
    for (var seatId in widget.selectedSeats) {
      passengerDetails[seatId] = {
        'name': '',
        'age': '',
        'gender': 'Male',
      };
    }
  }

  Future<void> _createRideOrder() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isCreatingOrder = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not authenticated';

      double distance;
      try {
        final cleanDistance = widget.distance.replaceAll(RegExp(r'[^0-9.]'), '');
        distance = double.parse(cleanDistance);
        
        if (distance <= 0) throw 'Invalid distance value';
      } catch (e) {
        throw 'Invalid distance format: ${widget.distance}';
      }

      final price = KLURideService.calculatePrice(distance, widget.vehicleType);

      final order = RideOrder(
        userId: user.uid,
        pickup: widget.startAddress,
        destination: widget.destinationAddress,
        distance: distance,
        price: price.round(),
        status: 'pending',
        pickupLocation: GeoPoint(widget.startPoint.latitude, widget.startPoint.longitude),
        destinationLocation: GeoPoint(widget.destination.latitude, widget.destination.longitude),
        vehicleType: widget.vehicleType,
        otp: KLURideService.generateOTP(),
        requestTime: DateTime.now(),
      );

      // Create the ride order
      final orderId = await _rideService.createRideOrder(order);

      // Save passenger details
      await FirebaseFirestore.instance
          .collection('klu_ride_orders')
          .doc(orderId)
          .collection('passengers')
          .add({
        'details': passengerDetails,
        'seats': widget.selectedSeats.toList(),
      });

      if (mounted) {
        // Navigate to ride status page
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => RideStatusPage(orderId: orderId),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create ride: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingOrder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Passenger Details',
          style: TextStyle(color: Colors.blue[900]),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue[900]),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: widget.selectedSeats.length,
                itemBuilder: (context, index) {
                  String seatId = widget.selectedSeats.elementAt(index);
                  return _buildPassengerCard(seatId, index + 1);
                },
              ),
            ),
            Container(
              padding: EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _isCreatingOrder ? null : _createRideOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isCreatingOrder
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Confirm Booking',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerCard(String seatId, int passengerNumber) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Passenger $passengerNumber (Seat: ${seatId.replaceAll('_', ' ').toUpperCase()})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter passenger name';
                }
                return null;
              },
              onSaved: (value) {
                passengerDetails[seatId]!['name'] = value!;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Age',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter passenger age';
                }
                if (int.tryParse(value) == null || int.parse(value) <= 0) {
                  return 'Please enter a valid age';
                }
                return null;
              },
              onSaved: (value) {
                passengerDetails[seatId]!['age'] = value!;
              },
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(),
              ),
              value: passengerDetails[seatId]!['gender'],
              items: ['Male', 'Female', 'Other']
                  .map((gender) => DropdownMenuItem(
                        value: gender,
                        child: Text(gender),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  passengerDetails[seatId]!['gender'] = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
} 