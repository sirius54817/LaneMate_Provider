import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ecub_delivery/pages/home.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class LocationUpdateManager {
  Timer? _locationUpdateTimer;
  final Location _location = Location();
  bool _isUpdatingLocation = false;
  RideOrder? currentOrder;

  void startLocationUpdates(RideOrder order) async {
    currentOrder = order;
    await _setupLocationUpdates();
  }

  void stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    _isUpdatingLocation = false;
    currentOrder = null;
  }

  Future<void> _setupLocationUpdates() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return;
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }

      _locationUpdateTimer = Timer.periodic(
        Duration(seconds: 20),
        (timer) async {
          if (!_isUpdatingLocation && currentOrder != null) {
            await _updateAgentLocation();
          }
        },
      );
    } catch (e) {
      debugPrint('Error setting up location updates: $e');
    }
  }

  Future<void> _updateAgentLocation() async {
    if (_isUpdatingLocation || currentOrder == null) return;
    
    try {
      _isUpdatingLocation = true;
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('No user logged in');
        return;
      }

      LocationData? locationData = await _location.getLocation().timeout(
        Duration(seconds: 30),
      );

      if (locationData.latitude == null || locationData.longitude == null) {
        debugPrint('Invalid location data received');
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      int updatedOrders = 0;

      // Update based on order type
      if (currentOrder!.orderType == 'medical') {
        try {
          final orderRef = FirebaseFirestore.instance
              .collection('me_orders')
              .doc(currentOrder!.customerName)
              .collection('orders')
              .doc(currentOrder!.orderId);

          final orderDoc = await orderRef.get();
          
          if (orderDoc.exists) {
            final orderData = orderDoc.data();
            if (orderData != null && 
                orderData['del_agent'] == currentUser.uid && 
                orderData['order_status'] == 'in_transit') {
              
              debugPrint('Updating location for medical order: ${currentOrder!.orderId} for customer: ${currentOrder!.customerName}');
              
              batch.update(orderRef, {
                'agent_location': GeoPoint(
                  locationData.latitude!,
                  locationData.longitude!,
                ),
                'last_location_update': FieldValue.serverTimestamp(),
              });
              
              updatedOrders++;
            }
          }
        } catch (e) {
          debugPrint('Error updating medical order location: $e');
        }
      } else {
        // Food order update logic
        try {
          final orderRef = FirebaseFirestore.instance
              .collection('orders')
              .doc(currentOrder!.orderId);

          batch.update(orderRef, {
            'agent_location': GeoPoint(
              locationData.latitude!,
              locationData.longitude!,
            ),
            'last_location_update': FieldValue.serverTimestamp(),
          });
          updatedOrders++;
        } catch (e) {
          debugPrint('Error updating food order location: $e');
        }
      }

      if (updatedOrders > 0) {
        await batch.commit();
        debugPrint('Location updated successfully for $updatedOrders orders');
      }

    } catch (e) {
      debugPrint('Error updating agent location: $e');
    } finally {
      _isUpdatingLocation = false;
    }
  }
}

class GoogleMapPage extends StatefulWidget {
  final RideOrder rideOrder;
  final String currentAgentId;

  const GoogleMapPage({
    Key? key,
    required this.rideOrder,
    required this.currentAgentId,
  }) : super(key: key);

  @override
  State<GoogleMapPage> createState() => _GoogleMapPageState();
}

class _GoogleMapPageState extends State<GoogleMapPage> {
  final locationController = Location();
  Timer? locationUpdateTimer;

  LatLng? currentPosition;
  LatLng? destinationPosition;
  Map<PolylineId, Polyline> polylines = {};
  BitmapDescriptor? currentLocationIcon;
  BitmapDescriptor? destinationIcon;
  String? eta; // Add a variable to store the ETA
  String? distance; // Add this line to store the distance

  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );

  final locationManager = LocationUpdateManager();
  bool _mapReady = false;
  bool _orderAccepted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      currentLocationIcon = await createBitmapDescriptorFromIcon(Icons.navigation);
      destinationIcon = await createBitmapDescriptorFromIcon(Icons.location_on);
      await initializeMap();
      await fetchAndStoreEstimatedTimeOfArrival();
      setState(() {});

      locationUpdateTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
        await fetchCurrentLocation();
        await updateLocationInFirestore();
      });

      // Start location updates with the current order
      locationManager.startLocationUpdates(widget.rideOrder);
    });
  }

  @override
  void dispose() {
    locationManager.stopLocationUpdates();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<BitmapDescriptor> createBitmapDescriptorFromIcon(
      IconData iconData) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const iconSize = 64.0;
    
    // Add a white circle background
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(iconSize/2, iconSize/2), iconSize/2, bgPaint);
    
    // Add a colored border
    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(iconSize/2, iconSize/2), iconSize/2 - 1.5, borderPaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: iconSize * 0.7,
        fontFamily: iconData.fontFamily,
        color: Colors.blue,
      ),
    );
    
    textPainter.layout();
    // Center the icon in the circle
    textPainter.paint(
      canvas, 
      Offset(
        (iconSize - textPainter.width) / 2,
        (iconSize - textPainter.height) / 2
      )
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(iconSize.toInt(), iconSize.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(bytes);
  }

  Future<void> initializeMap() async {
    try {
      await fetchCurrentLocation();
      await fetchDestinationCoordinates();
      final polylinePoints = await fetchPolylinePoints();
      await generatePolyLineFromPoints(polylinePoints);
      await fetchAndStoreEstimatedTimeOfArrival();
      
      setState(() {
        _mapReady = true;
      });
    } catch (e) {
      debugPrint('Error initializing map: $e');
    }
  }

  Future<void> fetchAndStoreEstimatedTimeOfArrival() async {
    final apiKey = 'AIzaSyApq25cUgw1k5tyFJVI4Ffd49bhg116rkc';
    final origin = '${currentPosition!.latitude},${currentPosition!.longitude}';
    final destination = '${destinationPosition!.latitude},${destinationPosition!.longitude}';
    final url = 'https://maps.googleapis.com/maps/api/distancematrix/json?origins=$origin&destinations=$destination&key=$apiKey';
//
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      debugPrint('API Response: $data');
      if (data['status'] == 'OK') {
        final elements = data['rows'][0]['elements'][0];
        if (elements['status'] == 'OK') {
          final duration = elements['duration']['text'];
          final distanceText = elements['distance']['text'];
          if (mounted) {
            setState(() {
              eta = duration;
              distance = distanceText;
            });
          }
          await storeETDInFirestore(duration, distanceText);
        } else {
          debugPrint('Error fetching ETA: ${elements['status']}');
        }
      } else {
        debugPrint('Error fetching ETA: ${data['status']}');
      }
    } else {
      debugPrint('Error fetching ETA: ${response.statusCode}');
    }
  }

  Future<void> storeETDInFirestore(String etd, String distance) async {
    try {
      final orderRef = FirebaseFirestore.instance
          .collection('ride_orders')
          .doc(widget.rideOrder.orderId);

      await orderRef.update({
        'etd': etd,
        'distance': distance,
        'last_updated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error storing ETD in Firestore: $e');
    }
  }

  Future<String?> getLoggedInUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  Future<void> updateOrderStatus(String status) async {
    try {
      if (status == 'in_transit') {
        final isAvailable = await _checkOrderAssignment();
        if (!isAvailable) return;

        if (_mapReady) {
          locationManager.startLocationUpdates(widget.rideOrder);
          setState(() {
            _orderAccepted = true;
          });
        }
      }

      final batch = FirebaseFirestore.instance.batch();
      
      // Update ride_orders collection
      final orderRef = FirebaseFirestore.instance
          .collection('ride_orders')
          .doc(widget.rideOrder.orderId);

      batch.update(orderRef, {
        'status': status,
        'rider_id': widget.currentAgentId,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // If completed, add to earnings
      if (status == 'completed') {
        final earningsRef = FirebaseFirestore.instance
            .collection('rider_earnings')
            .doc(widget.currentAgentId)
            .collection('earnings')
            .doc();

        batch.set(earningsRef, {
          'ride_id': widget.rideOrder.orderId,
          'amount': widget.rideOrder.price,
          'distance': widget.rideOrder.distance,
          'timestamp': FieldValue.serverTimestamp(),
          'pickup': widget.rideOrder.pickup,
          'destination': widget.rideOrder.destination,
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'completed' 
                ? 'Ride completed successfully!' 
                : 'Ride status updated'
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating order status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating ride status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> updateSalaryAndRides() async {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final String agentId = await getLoggedInUserId() ?? '';

    if (agentId.isEmpty) {
      debugPrint('User is not logged in');
      return;
    }

    try {
      DocumentReference agentRef = _firestore.collection('delivery_agent').doc(agentId);
      DocumentSnapshot agentSnapshot = await agentRef.get();

      if (agentSnapshot.exists) {
        int currentSalary = agentSnapshot['salary'] is int
            ? agentSnapshot['salary']
            : (agentSnapshot['salary'] as double).toInt();
        int currentRides = agentSnapshot['rides'] is int
            ? agentSnapshot['rides']
            : (agentSnapshot['rides'] as double).toInt();

        int updatedSalary = currentSalary + 30;
        int updatedRides = currentRides + 1;

        // Create delivery history entry
        Map<String, dynamic> deliveryEntry = {
          'timestamp': FieldValue.serverTimestamp(),
          'amount': 30, // The amount earned for this delivery
          'location': widget.rideOrder.address, // The delivery location
        };

        // Update the document with new salary, rides, and append to delivery history
        await agentRef.update({
          'salary': updatedSalary,
          'rides': updatedRides,
          'delivery_history': FieldValue.arrayUnion([deliveryEntry]),
        });

        debugPrint('Salary, rides, and delivery history updated successfully');
      } else {
        debugPrint('Agent document does not exist');
      }
    } catch (e) {
      debugPrint('Error updating salary and rides: $e');
    }
  }

  Future<void> updateLocationInFirestore() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      if (currentPosition == null) {
        debugPrint('Current position is null');
        return;
      }

      // Check order type and update accordingly
      if (widget.rideOrder.orderType == 'medical') {
        // For medical orders
        try {
          final orderRef = FirebaseFirestore.instance
              .collection('me_orders')
              .doc(widget.rideOrder.customerName)  // Use customer name as doc ID
              .collection('orders')
              .doc(widget.rideOrder.orderId);  // Use actual order ID

          final docSnapshot = await orderRef.get();
          if (!docSnapshot.exists) {
            throw 'Medical order document does not exist: ${widget.rideOrder.orderId}';
          }

          await orderRef.update({
            'agent_location': GeoPoint(
              currentPosition!.latitude,
              currentPosition!.longitude,
            ),
            'last_location_update': FieldValue.serverTimestamp(),
          });

          debugPrint('Updated medical order location successfully: ${widget.rideOrder.orderId}');
        } catch (e) {
          debugPrint('Error updating medical order location: $e');
        }
      } else {
        // For food orders (unchanged)
        try {
          final orderRef = FirebaseFirestore.instance
              .collection('orders')
              .doc(widget.rideOrder.orderId);

          final docSnapshot = await orderRef.get();
          if (!docSnapshot.exists) {
            throw 'Food order document does not exist: ${widget.rideOrder.orderId}';
          }

          await orderRef.update({
            'agent_location': GeoPoint(
              currentPosition!.latitude,
              currentPosition!.longitude,
            ),
            'last_location_update': FieldValue.serverTimestamp(),
          });

          debugPrint('Updated food order location successfully: ${widget.rideOrder.orderId}');
        } catch (e) {
          debugPrint('Error updating food order location: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in updateLocationInFirestore: $e');
    }
  }

  Future<bool?> _showDeliveryConfirmationDialog() async {
    String enteredOtp = '';
    bool isOtpValid = false;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Delivery'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Please confirm the delivery details:'),
                SizedBox(height: 10),
                Text('Customer: ${widget.rideOrder.customerName}'),
                Text('Address: ${widget.rideOrder.address}'),
                if (distance != null) Text('Distance: $distance'),
                SizedBox(height: 20),
                Text(
                  'Enter 6-digit OTP',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    6,
                    (index) => SizedBox(
                      width: 40,
                      child: TextField(
                        controller: _otpControllers[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        decoration: InputDecoration(
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          if (value.length == 1 && index < 5) {
                            FocusScope.of(context).nextFocus();
                          }
                          if (value.isEmpty && index > 0) {
                            FocusScope.of(context).previousFocus();
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                // Clear OTP fields
                _otpControllers.forEach((controller) => controller.clear());
                Navigator.of(context).pop(false);
              },
            ),
            ElevatedButton(
              child: Text('Verify & Confirm'),
              onPressed: () async {
                // Concatenate OTP
                enteredOtp = _otpControllers
                    .map((controller) => controller.text)
                    .join();

                // Verify OTP from Firestore
                try {
                  final orderDoc = await FirebaseFirestore.instance
                      .collection('orders')
                      .doc(widget.rideOrder.orderId)
                      .get();

                  if (!orderDoc.exists) {
                    throw 'Order not found';
                  }

                  final storedOtp = orderDoc.data()?['otp'];
                  isOtpValid = storedOtp == enteredOtp;

                  if (isOtpValid) {
                    // Clear OTP fields
                    _otpControllers.forEach((controller) => controller.clear());
                    Navigator.of(context).pop(true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Invalid OTP. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  logger.e('Error verifying OTP: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error verifying OTP: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<String?> _uploadDeliveryPhoto(XFile photo) async {
    try {
      final path = 'delivery_photos/${widget.rideOrder.orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(path);
      
      final file = File(photo.path);
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ride Details'),
      ),
      body: Column(
        children: [
          !_mapReady 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading map and route...'),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    currentPosition == null || destinationPosition == null
                        ? const Center(child: CircularProgressIndicator())
                        : GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: currentPosition!,
                              zoom: 13,
                            ),
                            markers: {
                              Marker(
                                markerId: const MarkerId('currentLocation'),
                                icon: currentLocationIcon ??
                                    BitmapDescriptor.defaultMarker,
                                position: currentPosition!,
                              ),
                              Marker(
                                markerId: const MarkerId('destinationLocation'),
                                icon: destinationIcon ?? BitmapDescriptor.defaultMarker,
                                position: destinationPosition!,
                              ),
                            },
                            polylines: Set<Polyline>.of(polylines.values),
                          ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10.0,
                              offset: Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ride to ${widget.rideOrder.destination}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Pickup: ${widget.rideOrder.pickup}'),
                            Text('Distance: ${widget.rideOrder.distance.toStringAsFixed(1)} km'),
                            Text('Price: ₹${widget.rideOrder.price}'),
                            if (eta != null) Text('ETA: $eta'),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  onPressed: () async {
                                    debugPrint('Accept button pressed');
                                    await updateOrderStatus('in_transit');
                                  },
                                  child: Text('Accept'),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    debugPrint('Delivered button pressed');
                                    
                                    if (widget.rideOrder.orderType == 'food') {
                                      // Show OTP dialog for food orders
                                      final confirmed = await _showDeliveryConfirmationDialog();
                                      if (confirmed == true) {
                                        try {
                                          await updateOrderStatus('delivered');
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(builder: (context) => HomeScreen()),
                                          );
                                        } catch (e) {
                                          debugPrint('Failed to complete delivery: $e');
                                        }
                                      }
                                    } else {
                                      // For medical orders, directly update status
                                      try {
                                        await updateOrderStatus('delivered');
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(builder: (context) => HomeScreen()),
                                        );
                                      } catch (e) {
                                        debugPrint('Failed to complete delivery: $e');
                                      }
                                    }
                                  },
                                  child: Text('Delivered'),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_orderAccepted)
                      Positioned(
                        top: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Tracking location...',
                              style: TextStyle(
                                color: Colors.green[900],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ],
      ),
    );
  }

  Future<void> fetchCurrentLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await locationController.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await locationController.requestService();
      if (!serviceEnabled) {
        debugPrint('Location service is not enabled');
        return;
      }
    }

    permissionGranted = await locationController.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await locationController.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        debugPrint('Location permission is not granted');
        return;
      }
    }

    LocationData locationData = await locationController.getLocation();
    setState(() {
      currentPosition = LatLng(locationData.latitude!, locationData.longitude!);
    });
    debugPrint('Current position: $currentPosition');
  }

  Future<LatLng?> fetchCoordinatesFromPlaceName(String address) async {
    try {
      // Use a valid API key
      final apiKey = 'AIzaSyApq25cUgw1k5tyFJVI4Ffd49bhg116rkc'; // Use the same API key you're using for Distance Matrix
      
      // Properly encode the address for URL
      final encodedAddress = Uri.encodeComponent(address);
      
      // Construct the Geocoding API URL
      final url = 'https://maps.googleapis.com/maps/api/geocode/json'
          '?address=$encodedAddress'
          '&key=$apiKey'
          '&region=in'; // Add region parameter for better results in India
      
      debugPrint('Fetching coordinates for address: $address');
      
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      
      debugPrint('Geocoding API response: ${response.body}');

      if (response.statusCode == 200) {
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          final lat = location['lat'] as double;
          final lng = location['lng'] as double;
          
          debugPrint('Successfully converted address to coordinates: ($lat, $lng)');
          return LatLng(lat, lng);
        } else {
          debugPrint('Geocoding API error: ${data['status']} - ${data['error_message'] ?? 'No results found for the address'}');
          return null;
        }
      } else {
        debugPrint('HTTP error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('Error in fetchCoordinatesFromPlaceName: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<List<LatLng>> fetchPolylinePoints() async {
    if (currentPosition == null || destinationPosition == null) {
      debugPrint('Error: Current or destination position is null');
      return [];
    }

    final polylinePoints = PolylinePoints();
    
    try {
      final result = await polylinePoints.getRouteBetweenCoordinates(
        'AIzaSyApq25cUgw1k5tyFJVI4Ffd49bhg116rkc', // Replace with your actual API key
        PointLatLng(currentPosition!.latitude, currentPosition!.longitude),
        PointLatLng(destinationPosition!.latitude, destinationPosition!.longitude),
      );

      if (result.points.isNotEmpty) {
        debugPrint('Polyline points fetched successfully');
        return result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
      } else {
        debugPrint('Error fetching polyline points: ${result.errorMessage}');
        return [];
      }
    } catch (e) {
      debugPrint('Error in fetchPolylinePoints: $e');
      return [];
    }
  }

  Future<void> generatePolyLineFromPoints(
      List<LatLng> polylineCoordinates) async {
    const PolylineId id = PolylineId('polyline');

    final Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.blueAccent,
      points: polylineCoordinates,
      width: 5,
    );

    if (mounted) {
      setState(() {
        polylines[id] = polyline;
      });
      debugPrint('Polyline added to the map');
    }
  }

  Future<bool> _checkOrderAssignment() async {
    try {
      // First check if we have a valid agent ID
      if (widget.currentAgentId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: No delivery agent ID found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      final DocumentReference orderRef;
      if (widget.rideOrder.orderType == 'medical') {
        orderRef = FirebaseFirestore.instance
            .collection('me_orders')
            .doc(widget.rideOrder.customerName)
            .collection('orders')
            .doc(widget.rideOrder.orderId);
      } else {
        orderRef = FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.rideOrder.orderId);
      }

      final docSnapshot = await orderRef.get();
      if (!docSnapshot.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: Order not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      final data = docSnapshot.data() as Map<String, dynamic>;
      final assignedAgent = data['del_agent'];

      // If there's no assigned agent, order is available
      if (assignedAgent == null || assignedAgent.toString().isEmpty) return true;

      // If this agent is assigned, order is available
      if (assignedAgent == widget.currentAgentId) return true;

      // If another agent is assigned, show dialog and return false
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Order Unavailable'),
              content: Text('This order has already been accepted by another delivery agent.'),
              actions: [
                TextButton(
                  child: Text('Refresh Orders'),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => HomeScreen()),
                    );
                  },
                ),
                TextButton(
                  child: Text('Go Back'),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Go back to home
                  },
                ),
              ],
            );
          },
        );
      }
      return false;
    } catch (e) {
      debugPrint('Error checking order assignment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking order status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<void> fetchDestinationCoordinates() async {
    try {
      if (widget.rideOrder.destination.isEmpty) {
        debugPrint('Error: Empty destination provided');
        return;
      }

      final coordinates = await fetchCoordinatesFromPlaceName(widget.rideOrder.destination);
      if (coordinates != null) {
        setState(() {
          destinationPosition = coordinates;
        });
      }
    } catch (e) {
      debugPrint('Error in fetchDestinationCoordinates: $e');
    }
  }
}
