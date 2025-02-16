import 'package:ecub_delivery/klu_page/home.dart';
import 'package:flutter/material.dart';
import 'package:ecub_delivery/services/orders_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:ecub_delivery/widgets/ride_map.dart';
import 'package:ecub_delivery/services/location_service.dart';
import 'package:flutter/services.dart';
import 'package:ecub_delivery/services/ride_service.dart';
import 'package:ecub_delivery/klu_page/ride_status.dart';
import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 50,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
);

class RideOrder {
  final String orderId;
  final String userId;
  final String pickup;
  final String destination;
  final double distance;
  final int price;
  final String status;
  final GeoPoint? pickupLocation;
  final GeoPoint? destinationLocation;
  final String? riderId;
  final String vehicleType;
  final String? otp;
  final DateTime? requestTime;
  final DateTime? acceptTime;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isCancelled;
  final String? cancellationReason;
  final double? convenienceFee;
  final double? cancellationFee;

  RideOrder({
    this.orderId = '',
    required this.userId,
    required this.pickup,
    required this.destination,
    required this.distance,
    required this.price,
    required this.status,
    this.pickupLocation,
    this.destinationLocation,
    this.riderId,
    required this.vehicleType,
    this.otp,
    this.requestTime,
    this.acceptTime,
    this.startTime,
    this.endTime,
    this.isCancelled = false,
    this.cancellationReason,
    this.convenienceFee,
    this.cancellationFee,
  });

  factory RideOrder.fromMap(Map<String, dynamic> map) {
    return RideOrder(
      orderId: map['docId'] ?? '',
      userId: map['user_id'] ?? '',
      pickup: map['pickup'] ?? '',
      destination: map['destination'] ?? '',
      distance: (map['distance'] ?? 0.0).toDouble(),
      price: map['calculatedPrice'] ?? 0,
      status: map['status'] ?? '',
      pickupLocation: map['pickup_location'] as GeoPoint?,
      destinationLocation: map['destination_location'] as GeoPoint?,
      riderId: map['rider_id'],
      vehicleType: map['vehicle_type'] ?? '4seater',
      otp: map['otp'],
      requestTime: (map['request_time'] as Timestamp?)?.toDate(),
      acceptTime: (map['accept_time'] as Timestamp?)?.toDate(),
      startTime: (map['start_time'] as Timestamp?)?.toDate(),
      endTime: (map['end_time'] as Timestamp?)?.toDate(),
      isCancelled: map['is_cancelled'] ?? false,
      cancellationReason: map['cancellation_reason'],
      convenienceFee: (map['convenience_fee'] ?? 0.0).toDouble(),
      cancellationFee: (map['cancellation_fee'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'pickup': pickup,
      'destination': destination,
      'distance': distance,
      'calculatedPrice': price,
      'status': status,
      'pickup_location': pickupLocation,
      'destination_location': destinationLocation,
      'rider_id': riderId,
      'vehicle_type': vehicleType,
      'otp': otp,
      'request_time': requestTime != null ? Timestamp.fromDate(requestTime!) : null,
      'accept_time': acceptTime != null ? Timestamp.fromDate(acceptTime!) : null,
      'start_time': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'end_time': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'is_cancelled': isCancelled,
      'cancellation_reason': cancellationReason,
      'convenience_fee': convenienceFee,
      'cancellation_fee': cancellationFee,
    };
  }

  static String getCollectionName(String? userEmail) {
    return userEmail?.endsWith('@klu.ac.in') == true 
        ? 'klu_ride_orders' 
        : 'ride_orders';
  }
}

class OrdersPage extends StatefulWidget {
  final bool isGivingRide;
  const   OrdersPage({
    super.key,
    required this.isGivingRide,
  });

  @override
  State<OrdersPage> createState() => _Ordersklu_pagetate();
}

class _Ordersklu_pagetate extends State<OrdersPage> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  int _selectedIndex = 0;
  bool _isGivingRide = false;
  final locationService = LocationService();
  final _completionOtpController = TextEditingController();
  bool _isVerifying = false;
  Stream<QuerySnapshot> _ordersStream = const Stream.empty();
  final _rideService = RideService();

  @override
  void initState() {
    super.initState();
    logger.i('Initializing Orders page');
    _checkRideMode();
    _initializeOrdersStream();
  }

  Future<void> _checkRideMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isGivingRide = prefs.getString('ride_mode') == 'give';
      });
      logger.i('Ride mode checked: ${_isGivingRide ? 'giving rides' : 'taking rides'}');
    } catch (e) {
      logger.e('Error checking ride mode', error: e);
    }
  }

  void _initializeOrdersStream() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        logger.w('Cannot initialize stream: No authenticated user');
        setState(() => _isLoading = false);
        return;
      }

      final userEmail = user.email;
      final collectionName = 'klu_ride_orders'; // Always use KLU collection for drivers
      
      logger.i('Initializing orders stream for driver: ${user.uid} from collection: $collectionName');

      Query query = FirebaseFirestore.instance.collection(collectionName);

      if (widget.isGivingRide) {
        // Show all pending rides without rider
        query = query
          .where('status', isEqualTo: 'pending')
          .where('rider_id', isNull: true);
      } else {
        // For passengers, keep existing logic
        logger.d('Filtering for passenger rides: ${_selectedIndex == 0 ? 'current' : 'completed'}');
        query = query
          .where('user_id', isEqualTo: user.uid)
          .where('status', whereIn: _selectedIndex == 0 
            ? ['pending', 'accepted', 'in_transit'] 
            : ['completed']); 
      }

      query = query.orderBy('request_time', descending: true);
      
      setState(() {
        _ordersStream = query.snapshots();
        _isLoading = false;
      });
      
      logger.i('Orders stream initialized successfully');
    } catch (e, stackTrace) {
      logger.e('Error initializing orders stream', error: e, stackTrace: stackTrace);
      setState(() => _isLoading = false);
    }
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
      _initializeOrdersStream();
    });
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabSelected(index),
        child: Container(
          margin: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[700] : Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.blue[200]!.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.blue[700],
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.blue[900],
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        toolbarHeight: 80,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Text(
              'LaneMate',
              style: TextStyle(
                color: Colors.blue[900],
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              ' • ',
              style: TextStyle(
                color: Colors.blue[300],
                fontSize: 22,
              ),
            ),
            Text(
              widget.isGivingRide ? 'KLU Ride Requests' : 'My Rides',
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: widget.isGivingRide ? null : PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.white,
            child: Row(
              children: [
                _buildTabButton(0, 'Current Ride', Icons.directions_car),
                _buildTabButton(1, 'Completed', Icons.check_circle),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _initializeOrdersStream,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(
              color: Colors.blue[700],
            ))
          : StreamBuilder<QuerySnapshot>(
              stream: _ordersStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  logger.e('Error in stream: ${snapshot.error}');
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final orders = snapshot.data?.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['docId'] = doc.id;
                  return data;
                }).toList() ?? [];

                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.isGivingRide
                            ? Icons.local_taxi
                            : _selectedIndex == 0
                              ? Icons.directions_car
                              : Icons.check_circle,
                          size: 64,
                          color: Colors.blue[200],
                        ),
                        SizedBox(height: 16),
                        Text(
                          widget.isGivingRide
                            ? 'No ride requests from KLU'
                            : 'No ${_selectedIndex == 0 ? "current" : "completed"} rides',
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    return _buildOrderCard(orders[index]);
                  },
                );
              },
            ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final bool isCompleted = order['status'] == 'completed';
    final bool isPending = order['status'] == 'pending';
    final bool isInTransit = order['status'] == 'in_transit';
    final bool isAccepted = order['status'] == 'accepted';
    
    Color getStatusColor() {
      if (isCompleted) return Colors.green;
      if (isInTransit) return Colors.blue;
      if (isAccepted) return Colors.orange;
      return Colors.grey;
    }

    String getStatusText() {
      if (isCompleted) return 'Completed';
      if (isInTransit) return 'In Transit';
      if (isAccepted) return 'Accepted';
      return 'Pending';
    }

    return GestureDetector(
      onTap: () {
        if (!widget.isGivingRide && _selectedIndex == 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RideStatusPage(orderId: order['docId']),
            ),
          );
        } else {
          _showRideDetails(order);
        }
      },
      child: Card(
        margin: EdgeInsets.only(bottom: 16),
        elevation: 2,
        child: InkWell(
          onTap: () {
            if (!widget.isGivingRide && _selectedIndex == 0) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RideStatusPage(orderId: order['docId']),
                ),
              );
            } else {
              _showRideDetails(order);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.all(16),
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isCompleted ? Icons.check_circle : 
                      isInTransit ? Icons.directions_car :
                      isAccepted ? Icons.access_time :
                      Icons.local_taxi,
                      color: Colors.blue[700],
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ride to ${order['destination'] ?? 'Unknown'}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: getStatusColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: getStatusColor().withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: getStatusColor(),
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              getStatusText(),
                              style: TextStyle(
                                color: getStatusColor(),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8),
                      if (widget.isGivingRide)
                        Text(
                          'Earnings: ₹${order['calculatedPrice']}',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.blue[900],
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        Text(
                          'Cost: ₹${order['calculatedPrice']}',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.blue[900],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      SizedBox(height: 4),
                      Text(
                        'Distance: ${order['distance']?.toStringAsFixed(1)} km',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      if (isCompleted && order['duration'] != null)
                        Text(
                          'Duration: ${order['duration']} mins',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                    ],
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.blue[700],
                    size: 20,
                  ),
                ),
                if (isPending && widget.isGivingRide)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16, left: 16, right: 16),
                    child: ElevatedButton(
                      onPressed: () => _acceptRide(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        minimumSize: Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Accept Ride',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (isInTransit && widget.isGivingRide)
                  Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: ElevatedButton(
                      onPressed: () => _showCompletionOTPDialog(order['docId']),
                      child: Text('Complete Ride'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _acceptRide(Map<String, dynamic> order) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        logger.w('Cannot accept ride: No authenticated user');
        return;
      }

      final collectionName = RideOrder.getCollectionName(currentUser.email);
      logger.i('Attempting to accept ride: ${order['docId']} from collection: $collectionName');
      
      // First check if the ride is still available
      final rideDoc = await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(order['docId'])
          .get();

      if (!rideDoc.exists) {
        logger.w('Ride no longer exists: ${order['docId']}');
        throw 'Ride no longer exists';
      }

      final rideData = rideDoc.data() as Map<String, dynamic>;
      if (rideData['status'] != 'pending' || rideData['rider_id'] != null) {
        logger.w('Ride is no longer available: ${order['docId']}');
        throw 'Ride is no longer available';
      }

      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(order['docId'])
          .update({
        'rider_id': currentUser.uid,
        'status': 'accepted',
        'accept_time': FieldValue.serverTimestamp(),
      });

      logger.i('Successfully accepted ride: ${order['docId']}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ride accepted successfully!')),
        );
        _initializeOrdersStream();

        // Start location streaming after successful acceptance
        _rideService.streamDriverLocation(currentUser.uid).listen(
          (location) {
            logger.d('Location updated: ${location.latitude}, ${location.longitude}');
          },
          onError: (error) {
            logger.e('Error streaming location', error: error);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error updating location: $error')),
              );
            }
          },
        );
      }
    } catch (e, stackTrace) {
      logger.e('Error accepting ride', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept ride: $e')),
        );
      }
    }
  }

  Future<void> _verifyCompletionOTP(String orderId, String enteredOTP) async {
    if (_isVerifying) return;

    setState(() => _isVerifying = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not authenticated';

      final collectionName = RideOrder.getCollectionName(user.email);
      logger.i('Verifying completion OTP for order: $orderId in collection: $collectionName');

      final rideDoc = await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(orderId)
          .get();

      final rideData = rideDoc.data() as Map<String, dynamic>;
      final storedOTP = rideData['otp'];

      if (enteredOTP != storedOTP) {
        throw 'Invalid OTP';
      }

      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(orderId)
          .update({
        'status': 'in_transit',
        'start_time': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ride started successfully! Showing route to destination.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      logger.e('Error verifying completion OTP', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing ride: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  void _showCompletionOTPDialog(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Enter Completion OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ask passenger for the completion OTP to end the ride',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _completionOtpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: 'Enter 6-digit OTP',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isVerifying 
                ? null 
                : () => _verifyCompletionOTP(orderId, _completionOtpController.text),
            child: _isVerifying
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Complete Ride'),
          ),
        ],
      ),
    );
  }

  void _showRideDetails(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RideDetailsSheet(
        order: order,
        isDriver: widget.isGivingRide,
      ),
    );
  }
}

// New widget for ride details
class RideDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  final bool isDriver;

  const RideDetailsSheet({
    Key? key,
    required this.order,
    required this.isDriver,
  }) : super(key: key);

  @override
  State<RideDetailsSheet> createState() => _RideDetailsSheetState();
}

class _RideDetailsSheetState extends State<RideDetailsSheet> {
  final _otpController = TextEditingController();
  bool _isVerifying = false;

  Future<void> _verifyOTPAndStartRide() async {
    if (_otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter OTP')),
      );
      return;
    }

    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter complete 6-digit OTP')),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      if (_otpController.text != widget.order['otp']) {
        throw 'Invalid OTP';
      }

      await FirebaseFirestore.instance
          .collection('ride_orders')
          .doc(widget.order['docId'])
          .update({
        'status': 'in_transit',
        'start_time': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ride started successfully! Showing route to destination.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _cancelRide() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not authenticated';

      final collectionName = RideOrder.getCollectionName(user.email);
      logger.i('Attempting to cancel ride: ${widget.order['docId']} in collection: $collectionName');

      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(widget.order['docId'])
          .update({
        'status': 'cancelled',
        'is_cancelled': true,
        'cancellation_reason': widget.isDriver ? 'Cancelled by driver' : 'Cancelled by passenger',
        'cancellation_time': FieldValue.serverTimestamp(),
      });

      logger.i('Successfully cancelled ride: ${widget.order['docId']}');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isDriver ? 'Ride cancelled by driver' : 'Ride cancelled',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      logger.e('Error cancelling ride', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling ride: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAccepted = widget.order['status'] == 'accepted';
    final bool isInTransit = widget.order['status'] == 'in_transit';
    
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          controller: controller,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 300,
                  child: RideMap(
                    startLocation: isInTransit ? 
                      widget.order['pickup_location'] : // Show full route in transit
                      widget.order['pickup_location'],
                    endLocation: isInTransit ? 
                      widget.order['destination_location'] : // Show destination in transit
                      widget.order['pickup_location'], // Show only pickup during acceptance
                    showFullRoute: isInTransit, // New parameter to show full route
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  isAccepted ? 'Pickup Location' : 
                  isInTransit ? 'Route to Destination' : 'Trip Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isInTransit)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Ride in Progress',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(height: 16),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildDetailRow('From', widget.order['pickup'] ?? 'N/A'),
                        Divider(height: 24),
                        _buildDetailRow('To', widget.order['destination'] ?? 'N/A'),
                        Divider(height: 24),
                        _buildDetailRow(
                          widget.isDriver ? 'Earnings' : 'Cost', 
                          '₹${widget.order['calculatedPrice']}'
                        ),
                        if (isInTransit) ...[
                          Divider(height: 24),
                          _buildDetailRow(
                            'Status', 
                            'In Transit',
                            valueColor: Colors.green[700],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (widget.isDriver && isAccepted)
                  Card(
                    margin: EdgeInsets.only(top: 16),
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Ask passenger for OTP',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Verify the OTP provided by the passenger to start the ride',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              letterSpacing: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter OTP',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              counterText: '',
                              contentPadding: EdgeInsets.symmetric(vertical: 16),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _isVerifying ? null : _verifyOTPAndStartRide,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              minimumSize: Size(double.infinity, 45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isVerifying
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Verify & Start Ride',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isAccepted || isInTransit)
                  Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: ElevatedButton(
                      onPressed: _cancelRide,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel Ride',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.blue[900],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
