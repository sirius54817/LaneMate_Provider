import 'package:ecub_delivery/pages/home.dart';
import 'package:flutter/material.dart';
import 'package:ecub_delivery/services/orders_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:ecub_delivery/widgets/ride_map.dart';
import 'package:ecub_delivery/services/location_service.dart';

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
  const OrdersPage({super.key});

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

      String orderStatus;
      switch (_selectedIndex) {
        case 0:
          orderStatus = 'pending';
          break;
        case 1:
          orderStatus = 'in_transit';
          break;
        case 2:
          orderStatus = 'completed';
          break;
        default:
          orderStatus = 'pending';
      }

      Query ordersQuery = FirebaseFirestore.instance.collection('ride_orders');
      
      if (_isGivingRide) {
        // For drivers, show their rides
        ordersQuery = ordersQuery.where('rider_id', isEqualTo: currentUser.uid);
      } else {
        // For passengers, show their requested rides
        ordersQuery = ordersQuery.where('user_id', isEqualTo: currentUser.uid);
      }
      
      ordersQuery = ordersQuery.where('status', isEqualTo: orderStatus);

      final QuerySnapshot ordersSnapshot = await ordersQuery.get();
      List<Map<String, dynamic>> orders = [];
      
      for (var doc in ordersSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['docId'] = doc.id;
        
        // Calculate statistics for completed rides
        if (orderStatus == 'completed') {
          final startTime = (data['start_time'] as Timestamp?)?.toDate();
          final endTime = (data['end_time'] as Timestamp?)?.toDate();
          
          if (startTime != null && endTime != null) {
            final duration = endTime.difference(startTime);
            data['duration'] = duration.inMinutes;
          }
        }
        
        orders.add(data);
      }

      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching orders: $e');
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
        isDriver: _isGivingRide,
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
              'Orders',
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
              children: [
                _buildTabButton(0, 'Available', Icons.local_shipping),
                _buildTabButton(1, 'Accepted', Icons.delivery_dining),
                _buildTabButton(2, 'Completed', Icons.check_circle),
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
                        _selectedIndex == 0 
                          ? Icons.delivery_dining 
                          : _selectedIndex == 1 ? Icons.delivery_dining : Icons.check_circle,
                        size: 64,
                        color: Colors.blue[200],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No ${_selectedIndex == 0 ? "available" : _selectedIndex == 1 ? "in-transit" : "completed"} orders',
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
        child: ListTile(
          contentPadding: EdgeInsets.all(16),
          leading: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isCompleted ? Icons.check_circle : Icons.directions_bike,
              color: Colors.blue[700],
            ),
          ),
          title: Text(
            'Ride to ${order['destination'] ?? 'Unknown'}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4),
              if (_isGivingRide)
                Text('Earnings: ₹${order['calculatedPrice']}')
              else
                Text('Cost: ₹${order['calculatedPrice']}'),
              Text('Distance: ${order['distance']?.toStringAsFixed(1)} km'),
              if (isCompleted && order['duration'] != null)
                Text('Duration: ${order['duration']} mins'),
            ],
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: Colors.blue[700],
            size: 20,
          ),
          onTap: () => _showRideDetails(order),
        ),
      ),
    );
  }
}

// New widget for ride details
class RideDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isDriver;

  const RideDetailsSheet({
    Key? key,
    required this.order,
    required this.isDriver,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              height: 300,
              child: RideMap(
                startLocation: order['pickup_location'],
                endLocation: order['destination_location'],
              ),
            ),
            SizedBox(height: 16),
            Text(
              isDriver ? 'Ride Statistics' : 'Trip Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _buildDetailRow('Distance', '${order['distance']?.toStringAsFixed(1)} km'),
            _buildDetailRow(
              isDriver ? 'Earnings' : 'Cost', 
              '₹${order['calculatedPrice']}'
            ),
            if (order['duration'] != null)
              _buildDetailRow('Duration', '${order['duration']} mins'),
            _buildDetailRow('From', order['pickup'] ?? 'N/A'),
            _buildDetailRow('To', order['destination'] ?? 'N/A'),
            if (order['start_time'] != null)
              _buildDetailRow(
                'Start Time',
                DateFormat('MMM d, h:mm a').format((order['start_time'] as Timestamp).toDate())
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.blue[900],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
