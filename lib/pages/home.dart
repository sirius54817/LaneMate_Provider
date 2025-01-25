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
import 'package:flutter/services.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'dart:ui' as ui;
import 'dart:math';

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
  
  final TextEditingController _startSearchController = TextEditingController();
  final TextEditingController _endSearchController = TextEditingController();
  List<Prediction> _startPredictions = [];
  List<Prediction> _endPredictions = [];
  bool _showStartSuggestions = false;
  bool _showEndSuggestions = false;
  bool _routeReady = false;

  // Add GoogleMapController
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _initializeMarkerIcons();
    _initializeLocation();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _startSearchController.dispose();
    _endSearchController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      await fetchCurrentLocation();
      if (currentPosition != null) {
        final address = await getAddressFromLatLng(currentPosition!);
        setState(() {
          _startSearchController.text = address ?? 'Current Location';
          _mapReady = true;
        });
      }
    } catch (e) {
      print('Error initializing location: $e');
      setState(() {
        _mapReady = true;  // Set map ready even if there's an error
      });
    }
  }

  Future<String?> getAddressFromLatLng(LatLng position) async {
    try {
      final apiKey = 'AIzaSyDBRvts55sYzQ0hcPcF0qp6ApnwW-hHmYo';
      final url = 'https://maps.googleapis.com/maps/api/geocode/json'
          '?latlng=${position.latitude},${position.longitude}'
          '&key=$apiKey';
      
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      
      if (data['status'] == 'OK') {
        return data['results'][0]['formatted_address'];
      }
      return null;
    } catch (e) {
      print('Error getting address: $e');
      return null;
    }
  }

  Future<void> _searchPlaces(String query, bool isStart) async {
    if (query.isEmpty) return;

    try {
      final apiKey = 'AIzaSyDBRvts55sYzQ0hcPcF0qp6ApnwW-hHmYo';
      final url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=$query'
          '&key=$apiKey'
          '&components=country:in';

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final predictions = (data['predictions'] as List)
            .map((p) => Prediction.fromJson(p))
            .toList();

        setState(() {
          if (isStart) {
            _startPredictions = predictions;
            _showStartSuggestions = true;
          } else {
            _endPredictions = predictions;
            _showEndSuggestions = true;
          }
        });
      }
    } catch (e) {
      print('Error searching places: $e');
    }
  }

  Future<void> _selectLocation(Prediction prediction, bool isStart) async {
    final coords = await fetchCoordinatesFromPlaceName(prediction.description!);
    if (coords != null) {
      setState(() {
        if (isStart) {
          currentPosition = coords;
          _startSearchController.text = prediction.description!;
          _showStartSuggestions = false;
        } else {
          destinationPosition = coords;
          _endSearchController.text = prediction.description!;
          _showEndSuggestions = false;
        }
      });
      
      if (currentPosition != null && destinationPosition != null) {
        await _updateRoute();
      }
    }
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
    if (_startSearchController.text.isEmpty || _endSearchController.text.isEmpty) {
      return;
    }

    try {
      // Get coordinates for destination
      if (_endSearchController.text != 'Current Location') {
        final destCoords = await fetchCoordinatesFromPlaceName(_endSearchController.text);
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

  Future<void> _initializeMarkerIcons() async {
    // Create custom arrow marker for current location
    final currentLocIcon = await _createCustomMarkerBitmap(
      Icons.navigation,
      Colors.white,
      Colors.blue[700] ?? Colors.blue,
    );
    
    setState(() {
      currentLocationIcon = currentLocIcon;
      destinationIcon = BitmapDescriptor.defaultMarker;
    });
  }

  Future<BitmapDescriptor> _createCustomMarkerBitmap(
    IconData iconData,
    Color iconColor,
    Color backgroundColor,
  ) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final size = 64.0;

    // Draw white circle background with shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(size/2, size/2 + 2), size/2 - 2, shadowPaint);

    // Draw white circle background
    final circlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size/2, size/2), size/2 - 2, circlePaint);

    // Draw colored border
    final borderPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(size/2, size/2), size/2 - 3, borderPaint);

    // Draw the arrow icon
    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: 36,
        fontFamily: iconData.fontFamily,
        color: backgroundColor,
        fontWeight: FontWeight.bold,
      ),
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  // Add this method to calculate bearing
  double _getBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * pi / 180;
    double lon1 = start.longitude * pi / 180;
    double lat2 = end.latitude * pi / 180;
    double lon2 = end.longitude * pi / 180;

    double dLon = lon2 - lon1;

    double y = sin(dLon) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    double bearing = atan2(y, x);
    bearing = bearing * 180 / pi;
    bearing = (bearing + 360) % 360;

    return bearing;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'LaneMate Rider',
          style: TextStyle(
            color: Colors.blue[900],
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search inputs container
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _startSearchController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.location_on, color: Colors.blue),
                    hintText: 'Start Location',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) => _searchPlaces(value, true),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _endSearchController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.location_on, color: Colors.red),
                    hintText: 'Destination',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) => _searchPlaces(value, false),
                ),
                if (eta != null && distance != null)
                  Container(
                    margin: EdgeInsets.only(top: 12),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.blue[50]!,
                          Colors.blue[100]!.withOpacity(0.5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue[200]!,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue[100]!.withOpacity(0.3),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: Colors.blue[700],
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Estimated Time',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  eta!,
                                  style: TextStyle(
                                    color: Colors.blue[900],
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          height: 24,
                          width: 1,
                          color: Colors.blue[200],
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.directions_car,
                              color: Colors.blue[700],
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Distance',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  distance!,
                                  style: TextStyle(
                                    color: Colors.blue[900],
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Map container
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: currentPosition ?? LatLng(20.5937, 78.9629),
                    zoom: 15,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                    if (currentPosition != null) {
                      controller.animateCamera(
                        CameraUpdate.newLatLngZoom(currentPosition!, 15),
                      );
                    }
                  },
                  markers: {
                    if (currentPosition != null)
                      Marker(
                        markerId: MarkerId('start'),
                        position: currentPosition!,
                        icon: currentLocationIcon ?? BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueBlue,
                        ),
                        rotation: 0,
                        anchor: Offset(0.5, 0.5),
                        flat: true,
                      ),
                    if (destinationPosition != null)
                      Marker(
                        markerId: MarkerId('end'),
                        position: destinationPosition!,
                        icon: BitmapDescriptor.defaultMarker,
                      ),
                  },
                  polylines: Set<Polyline>.of(polylines.values),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  zoomGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  mapType: MapType.normal,
                  minMaxZoomPreference: MinMaxZoomPreference(1, 20),
                  buildingsEnabled: true,
                  compassEnabled: true,
                  trafficEnabled: false,
                  mapToolbarEnabled: true,
                  onCameraMove: (CameraPosition position) {
                    // Optional: Handle camera movement
                  },
                  onCameraIdle: () {
                    // Optional: Handle when camera stops moving
                  },
                ),
                // Location suggestions overlays
                if (_showStartSuggestions && _startPredictions.isNotEmpty)
                  Positioned(
                    top: 0,
                    left: 16,
                    right: 16,
                    child: Card(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _startPredictions.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(_startPredictions[index].description!),
                            onTap: () => _selectLocation(_startPredictions[index], true),
                          );
                        },
                      ),
                    ),
                  ),
                if (_showEndSuggestions && _endPredictions.isNotEmpty)
                  Positioned(
                    top: 0,
                    left: 16,
                    right: 16,
                    child: Card(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _endPredictions.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(_endPredictions[index].description!),
                            onTap: () => _selectLocation(_endPredictions[index], false),
                          );
                        },
                      ),
                    ),
                  ),
                // Start Journey button
                if (currentPosition != null && destinationPosition != null)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: ElevatedButton(
                      onPressed: () {
                        print('Starting journey...');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Start Journey',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
