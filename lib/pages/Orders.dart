import 'package:ecub_delivery/pages/home.dart';
import 'package:flutter/material.dart';
import 'package:ecub_delivery/services/orders_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:ecub_delivery/widgets/ride_map.dart';
import 'package:ecub_delivery/services/location_service.dart';
import 'package:flutter/services.dart';

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
}

class OrdersPage extends StatefulWidget {
  final bool isGivingRide;
  const   OrdersPage({
    super.key,
    required this.isGivingRide,
  });

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  int _selectedIndex = 0;
  bool _isGivingRide = false; // To track if user is in "Give a Ride" mode
  final locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _checkRideMode();
    _fetchOrders();
  }

  Future<void> _checkRideMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGivingRide = prefs.getString('ride_mode') == 'give';
    });
  }

  Future<void> _fetchOrders() async {
    try {
      setState(() => _isLoading = true);

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw 'No authenticated user found';

      Query ordersQuery = FirebaseFirestore.instance.collection('ride_orders');

      // Handle different query cases
      if (widget.isGivingRide) {
        switch (_selectedIndex) {
          case 0: // Available rides
            ordersQuery = ordersQuery
              .where('status', isEqualTo: 'pending')
              .where('rider_id', isNull: true); // Only show unassigned rides
            break;
            
          case 1: // Accepted rides
            ordersQuery = ordersQuery
              .where('rider_id', isEqualTo: currentUser.uid)
              .where('status', whereIn: ['accepted', 'in_transit']);
            break;
            
          case 2: // Completed rides
            ordersQuery = ordersQuery
              .where('rider_id', isEqualTo: currentUser.uid)
              .where('status', isEqualTo: 'completed');
            break;
        }
      } else {
        // Passenger view
        ordersQuery = ordersQuery
          .where('user_id', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: _selectedIndex == 0 ? 'in_transit' : 'completed');
      }

      logger.d('Fetching orders with query: ${ordersQuery.parameters}');
      final QuerySnapshot ordersSnapshot = await ordersQuery.get();
      List<Map<String, dynamic>> orders = [];
      
      for (var doc in ordersSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['docId'] = doc.id;
        
        // Calculate statistics for completed rides
        if (data['status'] == 'completed') {
          final startTime = (data['start_time'] as Timestamp?)?.toDate();
          final endTime = (data['end_time'] as Timestamp?)?.toDate();
          
          if (startTime != null && endTime != null) {
            final duration = endTime.difference(startTime);
            data['duration'] = duration.inMinutes;
          }
        }
        
        orders.add(data);
      }

      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      logger.e('Error fetching orders', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _orders = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch orders: $e')),
        );
      }
    }
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

  Widget _buildTabButton(int index, String label, IconData icon) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedIndex != index) {
            setState(() {
              _selectedIndex = index;
              _fetchOrders();
            });
          }
        },
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
              widget.isGivingRide ? 'Available Rides' : 'My Rides',
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.white,
            child: Row(
              children: widget.isGivingRide 
                ? [
                    _buildTabButton(0, 'Available', Icons.local_taxi),
                    _buildTabButton(1, 'Accepted', Icons.directions_car),
                    _buildTabButton(2, 'Completed', Icons.check_circle),
                  ]
                : [
                    _buildTabButton(0, 'Current Ride', Icons.directions_car),
                    _buildTabButton(1, 'Completed', Icons.check_circle),
                  ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(
              color: Colors.blue[700],
            ))
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.isGivingRide
                          ? _selectedIndex == 0 
                            ? Icons.local_taxi
                            : _selectedIndex == 1 
                              ? Icons.directions_car 
                              : Icons.check_circle
                          : _selectedIndex == 0
                            ? Icons.directions_car
                            : Icons.check_circle,
                        size: 64,
                        color: Colors.blue[200],
                      ),
                      SizedBox(height: 16),
                      Text(
                        widget.isGivingRide
                          ? 'No ${_selectedIndex == 0 ? "available" : _selectedIndex == 1 ? "accepted" : "completed"} rides'
                          : 'No ${_selectedIndex == 0 ? "current" : "completed"} rides',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    return _buildOrderCard(order);
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

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white,
              Colors.blue[50]!.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
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
              onTap: () => _showRideDetails(order),
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
          ],
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

      logger.i('Attempting to accept ride: ${order['docId']}');
      
      // First check if the ride is still available
      final rideDoc = await FirebaseFirestore.instance
          .collection('ride_orders')
          .doc(order['docId'])
          .get();

      if (!rideDoc.exists) {
        throw 'Ride no longer exists';
      }

      final rideData = rideDoc.data() as Map<String, dynamic>;
      if (rideData['status'] != 'pending' || rideData['rider_id'] != null) {
        throw 'Ride is no longer available';
      }

      await FirebaseFirestore.instance
          .collection('ride_orders')
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
        _fetchOrders(); // Refresh the list
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
    if (widget.isDriver) {
      // Show confirmation dialog for drivers
      final bool? confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Text(
              'Cancel Ride',
              style: TextStyle(
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to cancel this ride?',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'This action cannot be undone.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'No, Keep Ride',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Yes, Cancel',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('ride_orders')
          .doc(widget.order['docId'])
          .update({
        'status': 'cancelled',
        'is_cancelled': true,
        'cancellation_reason': widget.isDriver ? 'Cancelled by driver' : 'Cancelled by passenger',
        'cancellation_time': FieldValue.serverTimestamp(),
      });

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
    } catch (e) {
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
                            'Enter OTP to Start Ride',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
                              hintText: '6-digit OTP',
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
