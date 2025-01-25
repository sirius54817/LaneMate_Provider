import 'package:ecub_delivery/pages/init.dart';
import 'package:ecub_delivery/pages/navigation.dart';
import 'package:ecub_delivery/services/orders_service.dart';
import 'package:flutter/material.dart';
import 'package:ecub_delivery/pages/Earnings.dart';
import 'package:ecub_delivery/pages/Orders.dart';
import 'package:ecub_delivery/pages/login.dart';
import 'package:ecub_delivery/pages/profile.dart';
import 'package:ecub_delivery/services/auth_service.dart';
import 'package:ecub_delivery/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final logger = Logger();

class OrdersSam {
  final String orderId;
  final String itemName;
  final String customerName;
  final String itemPrice;
  final String address;
  final String vendor;
  String status;
  final int itemCount;
  final bool isVeg;
  final String location;
  final Map<String, dynamic> prepTime;
  final String timestamp;
  final Map<String, dynamic>? orderSummary;
  final String paymentStatus;
  final String orderType;

  OrdersSam({
    required this.orderId,
    required this.itemName,
    required this.customerName,
    required this.itemPrice,
    required this.address,
    required this.vendor,
    required this.status,
    required this.itemCount,
    required this.isVeg,
    required this.location,
    required this.prepTime,
    required this.timestamp,
    this.orderSummary,
    this.paymentStatus = 'pending',
    required this.orderType,
  });

  static OrdersSam fromMap(Map<String, dynamic> order, {bool isMedical = false}) {
    if (isMedical) {
      try {
        print("Processing medical order data: $order");
        
        Map<String, dynamic> firstItem = {};
        if (order['order_summary'] != null && order['order_summary'] is Map) {
          final orderSummary = order['order_summary'] as Map;
          if (orderSummary.isNotEmpty) {
            final firstItemKey = orderSummary.keys.first;
            firstItem = orderSummary[firstItemKey] as Map<String, dynamic>;
          }
        }

        // Use order_time for timestamp if available
        final timestamp = order['order_time'] ?? order['timestamp'] ?? DateTime.now().toIso8601String();

        return OrdersSam(
          orderId: order['order_id'] ?? order['docId'] ?? '',
          itemName: firstItem['name'] ?? 'Unknown Item',
          customerName: order['userId'] ?? 'Unknown Customer',
          itemPrice: (order['totalPrice'] ?? 0).toString(),
          address: order['delivery_address'] ?? '',
          vendor: firstItem['storeName'] ?? 'Unknown Store',
          status: order['status'] ?? 'unknown',
          itemCount: firstItem['quantity'] ?? 1,
          isVeg: false,
          location: order['delivery_address'] ?? '',
          prepTime: {'min': 15, 'max': 30},
          timestamp: timestamp,
          orderSummary: order['order_summary'],
          paymentStatus: order['payment_status'] ?? 'pending',
          orderType: 'medical',
        );
      } catch (e) {
        print("Error creating OrdersSam from medical order: $e");
        rethrow;
      }
    }

    // Food orders
    int itemCount;
    if (order['itemCount'] is double) {
      itemCount = (order['itemCount'] as double).toInt();
    } else if (order['itemCount'] is int) {
      itemCount = order['itemCount'];
    } else {
      itemCount = 1;
    }

    return OrdersSam(
      orderId: order['docId'] ?? '',
      itemName: order['itemName'] ?? '',
      customerName: order['userId'] ?? '',
      itemPrice: (order['itemPrice'] ?? 0).toString(),
      address: order['address'] ?? '',
      vendor: order['vendor'] ?? '',
      status: order['status'] ?? '',
      itemCount: itemCount,
      isVeg: order['isVeg'] ?? false,
      location: order['location'] ?? '',
      prepTime: order['prepTime'] ?? {'min': 15, 'max': 30},
      timestamp: order['timestamp'] ?? '',
      orderType: 'food',
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _user;
  bool _loading = true;
  bool _isRefreshing = false;
  late AnimationController _rotationController;
  LatLng? currentPosition;
  LatLng? destinationPosition;
  Map<PolylineId, Polyline> polylines = {};
  BitmapDescriptor? currentLocationIcon;
  BitmapDescriptor? destinationIcon;
  String? eta;
  String? distance;
  bool _mapReady = false;
  final Location locationController = Location();
  
  final TextEditingController _startLocationController = TextEditingController();
  final TextEditingController _endLocationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _fetchUserData();
    _initializeMap();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _startLocationController.dispose();
    _endLocationController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
      print("Fetching user data...");
      if (!mounted) return;

      setState(() {
        _loading = true;
      });

      // Get current user's email
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw 'No authenticated user found';
      }

      // Query Firestore for delivery agent data
      final agentSnapshot = await FirebaseFirestore.instance
          .collection('delivery_agent')
          .where('email', isEqualTo: currentUser.email)
          .get();

      if (agentSnapshot.docs.isEmpty) {
        throw 'No delivery agent found for this email';
      }

      // Get the first matching document
      final agentData = agentSnapshot.docs.first.data();
      
      if (!mounted) return;

      setState(() {
        _user = {
          'name': agentData['name'] ?? 'Unknown',
          'photoURL': agentData['photoURL'],
          'email': currentUser.email,
          'salary': agentData['salary'] ?? 0,
          'rides': agentData['rides'] ?? 0,
        };
        _loading = false;
      });
      
      print("User data fetched successfully: ${_user.toString()}");
    } catch (e) {
      print("Error fetching user data: $e");
      if (!mounted) return;

      setState(() {
        _loading = false;
        _user = {
          'name': 'Error loading data',
          'salary': 0,
          'rides': 0,
        };
      });

      // Move SnackBar to the next frame to ensure Scaffold is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load user data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  Future<void> _refreshOrders() async {
    if (_isRefreshing || !mounted) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _fetchUserData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data refreshed'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _initializeMap() async {
    await fetchCurrentLocation();
    setState(() {
      _mapReady = true;
      // Set initial start location to current location
      if (currentPosition != null) {
        _startLocationController.text = 'Current Location';
      }
    });
  }

  Future<void> fetchCurrentLocation() async {
    bool serviceEnabled = await locationController.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await locationController.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await locationController.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await locationController.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    LocationData locationData = await locationController.getLocation();
    setState(() {
      currentPosition = LatLng(locationData.latitude!, locationData.longitude!);
    });
  }

  Future<void> _updateRoute() async {
    if (_startLocationController.text.isEmpty || _endLocationController.text.isEmpty) {
      return;
    }

    try {
      // Get coordinates for destination
      if (_endLocationController.text != 'Current Location') {
        final destCoords = await fetchCoordinatesFromPlaceName(_endLocationController.text);
        if (destCoords != null) {
          destinationPosition = destCoords;
        }
      }

      if (currentPosition != null && destinationPosition != null) {
        // Fetch and draw route
        final points = await fetchPolylinePoints();
        await generatePolyLineFromPoints(points);
        await fetchAndStoreEstimatedTimeOfArrival();
        setState(() {});
      }
    } catch (e) {
      print('Error updating route: $e');
    }
  }

  Future<LatLng?> fetchCoordinatesFromPlaceName(String address) async {
    try {
      final apiKey = 'AIzaSyDBRvts55sYzQ0hcPcF0qp6ApnwW-hHmYo';
      final encodedAddress = Uri.encodeComponent(address);
      final url = 'https://maps.googleapis.com/maps/api/geocode/json'
          '?address=$encodedAddress'
          '&key=$apiKey'
          '&region=in';
      
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == 'OK' && data['results'].isNotEmpty) {
        final location = data['results'][0]['geometry']['location'];
        return LatLng(location['lat'], location['lng']);
      }
      return null;
    } catch (e) {
      print('Error in fetchCoordinatesFromPlaceName: $e');
      return null;
    }
  }

  Future<List<LatLng>> fetchPolylinePoints() async {
    if (currentPosition == null || destinationPosition == null) return [];

    final polylinePoints = PolylinePoints();
    try {
      final result = await polylinePoints.getRouteBetweenCoordinates(
        'AIzaSyDBRvts55sYzQ0hcPcF0qp6ApnwW-hHmYo',
        PointLatLng(currentPosition!.latitude, currentPosition!.longitude),
        PointLatLng(destinationPosition!.latitude, destinationPosition!.longitude),
      );

      return result.points
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
    } catch (e) {
      print('Error in fetchPolylinePoints: $e');
      return [];
    }
  }

  Future<void> generatePolyLineFromPoints(List<LatLng> polylineCoordinates) async {
    const PolylineId id = PolylineId('poly');
    final Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.blue,
      points: polylineCoordinates,
      width: 3,
    );

    setState(() {
      polylines[id] = polyline;
    });
  }

  Future<void> fetchAndStoreEstimatedTimeOfArrival() async {
    if (currentPosition == null || destinationPosition == null) return;

    final apiKey = 'AIzaSyDBRvts55sYzQ0hcPcF0qp6ApnwW-hHmYo';
    final origin = '${currentPosition!.latitude},${currentPosition!.longitude}';
    final destination = '${destinationPosition!.latitude},${destinationPosition!.longitude}';
    final url = 'https://maps.googleapis.com/maps/api/distancematrix/json'
        '?origins=$origin'
        '&destinations=$destination'
        '&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final elements = data['rows'][0]['elements'][0];
          if (elements['status'] == 'OK') {
            setState(() {
              eta = elements['duration']['text'];
              distance = elements['distance']['text'];
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching ETA: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        toolbarHeight: 80,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'ECUB Delivery',
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
              (_user?['name'] ?? 'Loading...').split(' ').take(2).join(' '),
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isRefreshing 
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.blue[700],
                    strokeWidth: 2,
                  ),
                )
              : Icon(Icons.refresh, color: Colors.blue[700]),
            onPressed: _refreshOrders,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16, 48, 16, 16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'ECUB Delivery',
                      style: TextStyle(
                        color: Colors.blue[900],
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Location input fields
                TextField(
                  controller: _startLocationController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.location_on, color: Colors.blue),
                    hintText: 'Start Location',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _endLocationController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.location_on, color: Colors.red),
                    hintText: 'End Location',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) => _updateRoute(),
                ),
                if (eta != null && distance != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'ETA: $eta • Distance: $distance',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: !_mapReady
                ? Center(child: CircularProgressIndicator())
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: currentPosition ?? LatLng(20.5937, 78.9629), // India
                      zoom: 15,
                    ),
                    markers: {
                      if (currentPosition != null)
                        Marker(
                          markerId: MarkerId('start'),
                          position: currentPosition!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueBlue,
                          ),
                        ),
                      if (destinationPosition != null)
                        Marker(
                          markerId: MarkerId('end'),
                          position: destinationPosition!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueRed,
                          ),
                        ),
                    },
                    polylines: Set<Polyline>.of(polylines.values),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                  ),
          ),
        ],
      ),
    );
  }
}
