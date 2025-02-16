import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/ride_service.dart';
import '../widgets/ride_map.dart';
import 'package:intl/intl.dart';

class RideStatusPage extends StatefulWidget {
  final String orderId;

  const RideStatusPage({Key? key, required this.orderId}) : super(key: key);

  @override
  State<RideStatusPage> createState() => _RideStatusklu_pagetate();
}

class _RideStatusklu_pagetate extends State<RideStatusPage> {
  late Stream<DocumentSnapshot> _orderStream;
  Stream<DocumentSnapshot>? _driverLocationStream;
  final _otpController = TextEditingController();
  final RideService _rideService = RideService();
  bool _isVerifyingOTP = false;

  @override
  void initState() {
    super.initState();
    _orderStream = FirebaseFirestore.instance
        .collection('ride_orders')
        .doc(widget.orderId)
        .snapshots();
    
    // Initialize driver location stream
    _orderStream.listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final riderId = data['rider_id'];
        if (riderId != null) {
          setState(() {
            _driverLocationStream = FirebaseFirestore.instance
                .collection('driver_locations')
                .doc(riderId)
                .snapshots();
          });
        }
      }
    });
  }

  Future<void> _cancelRide(Map<String, dynamic> orderData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      bool confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Cancel Ride?'),
          content: Text(
            orderData['rider_id'] != null
                ? 'Cancelling now will incur a ₹${RideService.CANCELLATION_FEE} charge.'
                : 'Are you sure you want to cancel this ride?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Yes, Cancel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await FirebaseFirestore.instance
            .collection('ride_orders')
            .doc(widget.orderId)
            .update({
          'status': 'cancelled',
          'is_cancelled': true,
          'cancellation_reason': 'User cancelled',
          'cancellation_fee': orderData['rider_id'] != null 
              ? RideService.CANCELLATION_FEE 
              : 0,
          'cancel_time': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel ride: $e')),
      );
    }
  }

  Future<void> _verifyOTP(String orderId, String enteredOTP) async {
    if (_isVerifyingOTP) return;

    setState(() => _isVerifyingOTP = true);

    try {
      final success = await _rideService.startRide(orderId, enteredOTP);
      
      if (mounted) {
        if (success) {
          Navigator.pop(context); // Close OTP dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ride started successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid OTP. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error verifying OTP: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifyingOTP = false);
      }
    }
  }

  Future<void> _retryBooking() async {
    try {
      final success = await _rideService.retryBooking(widget.orderId);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Booking retried successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to retry booking. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error retrying booking: $e')),
        );
      }
    }
  }

  void _showOTPDialog(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Enter OTP'),
        content: TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            hintText: 'Enter 6-digit OTP',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isVerifyingOTP 
                ? null 
                : () => _verifyOTP(orderId, _otpController.text),
            child: _isVerifyingOTP
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Verify'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ride Status',style: TextStyle(fontWeight: FontWeight.bold),),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[900],
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _orderStream,
        builder: (context, orderSnapshot) {
          if (orderSnapshot.hasError) {
            return Center(child: Text('Error: ${orderSnapshot.error}'));
          }

          if (!orderSnapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final orderData = orderSnapshot.data!.data() as Map<String, dynamic>;
          final status = orderData['status'] as String;

          return Column(
            children: [
              if (orderData['pickup_location'] != null && 
                  orderData['destination_location'] != null)
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: _driverLocationStream,
                    builder: (context, locationSnapshot) {
                      LatLng? driverLocation;
                      if (locationSnapshot.hasData && locationSnapshot.data!.exists) {
                        final locationData = locationSnapshot.data!.data() as Map<String, dynamic>;
                        driverLocation = LatLng(
                          locationData['latitude'] ?? 0,
                          locationData['longitude'] ?? 0,
                        );
                      }

                      return RideMap(
                        startLocation: orderData['pickup_location'],
                        endLocation: orderData['destination_location'],
                        driverLocation: driverLocation,
                        showDriverLocation: status == 'accepted' || status == 'in_transit',
                      );
                    },
                  ),
                ),

              // Status and actions container
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatusIndicator(status, orderData),
                    SizedBox(height: 16),
                    _buildRideDetails(orderData),
                    SizedBox(height: 16),
                    if (status == 'pending')
                      ElevatedButton(
                        onPressed: () => _cancelRide(orderData),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cancel, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Cancel Ride', 
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    if (status == 'accepted' && orderData['otp'] != null)
                      ElevatedButton(
                        onPressed: () => _showOTPDialog(widget.orderId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('Enter OTP to Start Ride'),
                      ),
                    if (status == 'expired')
                      ElevatedButton(
                        onPressed: _retryBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Retry Booking', 
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusIndicator(String status, Map<String, dynamic> orderData) {
    Color color;
    String message;
    IconData icon;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        message = 'Waiting for driver...';
        icon = Icons.access_time;
        break;
      case 'accepted':
        color = Colors.blue;
        message = 'Driver is on the way';
        icon = Icons.directions_car;
        break;
      case 'in_transit':
        color = Colors.green;
        message = 'Ride in progress';
        icon = Icons.local_taxi;
        break;
      case 'completed':
        color = Colors.green;
        message = 'Ride completed';
        icon = Icons.check_circle;
        break;
      case 'cancelled':
        color = Colors.red;
        message = 'Ride cancelled';
        icon = Icons.cancel;
        break;
    case 'rejected':
        color = Colors.red;
        message = 'Ride rejected';
        icon = Icons.cancel;
        break;
    case 'expired':
        color = Colors.orange;
        message = 'Ride expired';
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        message = 'Unknown status';
        icon = Icons.help;
    }

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              SizedBox(width: 12),
              Text(
                message,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          // Show start ride OTP
          if (status == 'accepted')
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Share OTP with driver: ',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${orderData['otp'] ?? 'N/A'}',
                    style: TextStyle(
                      color: Colors.blue[900],
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          // Show completion OTP
          if (status == 'in_transit')
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Completion OTP: ',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${orderData['completion_otp'] ?? 'N/A'}',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRideDetails(Map<String, dynamic> orderData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ride Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
          ),
        ),
        SizedBox(height: 12),
        _buildDetailRow('From', orderData['pickup'] ?? 'Unknown'),
        _buildDetailRow('To', orderData['destination'] ?? 'Unknown'),
        _buildDetailRow(
          'Distance', 
          '${orderData['distance']?.toStringAsFixed(1) ?? 'Unknown'} km'
        ),
        _buildDetailRow(
          'Price', 
          '₹${orderData['calculatedPrice'] ?? 'Unknown'}'
        ),
        if (orderData['rider_id'] != null)
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(orderData['rider_id'])
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return SizedBox();
              final userData = snapshot.data!.data() as Map<String, dynamic>?;
              return _buildDetailRow(
                'Driver',
                userData?['name'] ?? 'Unknown Driver',
              );
            },
          ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.blue[900],
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.visible,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
} 