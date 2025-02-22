import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ecub_delivery/klu_page/seat_layout.dart';
import '../services/klu_ride_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../klu_page/Orders.dart';
import 'package:ecub_delivery/klu_page/ride_status.dart';

class VehicleSelectionPage extends StatefulWidget {
  final LatLng startPoint;
  final LatLng destination;
  final String startAddress;
  final String destinationAddress;
  final String distance;
  final String duration;

  const VehicleSelectionPage({
    Key? key,
    required this.startPoint,
    required this.destination,
    required this.startAddress,
    required this.destinationAddress,
    required this.distance,
    required this.duration,
  }) : super(key: key);

  @override
  State<VehicleSelectionPage> createState() => _VehicleSelectionklu_pagetate();
}

class _VehicleSelectionklu_pagetate extends State<VehicleSelectionPage> {
  final KLURideService _rideService = KLURideService();
  String _selectedVehicle = 'bus';
  bool _isCreatingOrder = false;
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _checkDataLoaded();
  }

  void _checkDataLoaded() {
    setState(() {
      _isDataLoaded = widget.distance.isNotEmpty && 
                      widget.duration.isNotEmpty &&
                      widget.distance != '0' &&
                      widget.duration != '0';
    });
  }

  Future<void> _createRideOrder() async {
    setState(() => _isCreatingOrder = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not authenticated';

      final distance = double.parse(widget.distance.replaceAll(RegExp(r'[^0-9.]'), ''));
      final price = KLURideService.calculatePrice(distance, _selectedVehicle);
      
      final order = RideOrder(
        userId: user.uid,
        pickup: widget.startAddress,
        destination: widget.destinationAddress,
        distance: distance,
        price: price.round(),
        status: 'pending',
        pickupLocation: GeoPoint(widget.startPoint.latitude, widget.startPoint.longitude),
        destinationLocation: GeoPoint(widget.destination.latitude, widget.destination.longitude),
        vehicleType: _selectedVehicle,
        otp: KLURideService.generateOTP(),
        requestTime: DateTime.now(),
      );

      final orderId = await _rideService.createRideOrder(order);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RideStatusPage(orderId: orderId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create ride: $e')),
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
        title: Text('Select Vehicle'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[900],
      ),
      body: Column(
        children: [
          // Journey Details Card
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildAddressRow(Icons.location_on, 'From', widget.startAddress),
                SizedBox(height: 12),
                _buildAddressRow(Icons.location_on, 'To', widget.destinationAddress),
                Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTripDetail(
                      Icons.timeline,
                      widget.distance,
                      'Distance',
                    ),
                    Container(
                      height: 30,
                      width: 1,
                      color: Colors.grey[300],
                    ),
                    _buildTripDetail(
                      Icons.access_time,
                      widget.duration,
                      'Duration',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bus Option Card
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: GestureDetector(
                onTap: _isDataLoaded ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SeatLayoutPage(
                        vehicleType: VehicleType.bus,
                        startAddress: widget.startAddress,
                        destinationAddress: widget.destinationAddress,
                        distance: widget.distance,
                        duration: widget.duration,
                        startPoint: widget.startPoint,
                        destination: widget.destination,
                      ),
                    ),
                  );
                } : null,
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isDataLoaded ? Colors.white : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isDataLoaded ? Colors.blue.withOpacity(0.1) : Colors.grey[300]!,
                    ),
                    boxShadow: _isDataLoaded ? [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ] : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'KLU Bus',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _isDataLoaded ? Colors.blue[900] : Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '40 Seats',
                              style: TextStyle(
                                color: _isDataLoaded ? Colors.blue[700] : Colors.grey[500],
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              _isDataLoaded 
                                ? 'Comfortable college bus service with AC'
                                : 'Waiting for route calculation...',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            if (_isDataLoaded) ...[
                              SizedBox(height: 16),
                              Text(
                                'Features:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[900],
                                ),
                              ),
                              SizedBox(height: 8),
                              _buildFeatureRow(Icons.ac_unit, 'Air Conditioned'),
                              _buildFeatureRow(Icons.airline_seat_recline_extra, 'Comfortable Seating'),
                              _buildFeatureRow(Icons.security, 'Safe & Secure'),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.directions_bus,
                        size: 80,
                        color: _isDataLoaded ? Colors.blue[300] : Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.blue[700],
          ),
          SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(IconData icon, String label, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blue[700], size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Text(
                address,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTripDetail(IconData icon, String value, String label) {
    final bool hasValue = value.isNotEmpty && value != '0';
    
    return Column(
      children: [
        Icon(icon, color: hasValue ? Colors.blue[700] : Colors.grey[400], size: 24),
        SizedBox(height: 4),
        hasValue 
          ? Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            )
          : SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
              ),
            ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}