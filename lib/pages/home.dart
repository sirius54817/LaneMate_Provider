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
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:ecub_delivery/pages/vehicle_selection.dart';

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

enum RideMode {
  take,
  give
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

  RideMode _currentMode = RideMode.take;

  Timer? _locationTimer;
  final Location _location = Location();

  // Add focus nodes for text fields
  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _endFocusNode = FocusNode();

  // Add a property to track if suggestions are showing
  bool get isSuggestionsVisible => _showStartSuggestions || _showEndSuggestions;

  @override
  void initState() {
    super.initState();
    _loadSavedMode();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _initializeMarkerIcons();
    _initializeLocation();
    _startLocationUpdates();

    // Add listeners to focus nodes
    _startFocusNode.addListener(_onStartFocusChange);
    _endFocusNode.addListener(_onEndFocusChange);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _startSearchController.dispose();
    _endSearchController.dispose();
    _locationTimer?.cancel();
    _startFocusNode.removeListener(_onStartFocusChange);
    _endFocusNode.removeListener(_onEndFocusChange);
    _startFocusNode.dispose();
    _endFocusNode.dispose();
    super.dispose();
  }

  void _onStartFocusChange() {
    if (!_startFocusNode.hasFocus) {
      setState(() {
        _showStartSuggestions = false;
      });
    }
  }

  void _onEndFocusChange() {
    if (!_endFocusNode.hasFocus) {
      setState(() {
        _showEndSuggestions = false;
      });
    }
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
      final apiKey = 'AIzaSyApq25cUgw1k5tyFJVI4Ffd49bhg116rkc';
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
    // Clear suggestions if query is empty
    if (query.isEmpty) {
      setState(() {
        if (isStart) {
          _startPredictions = [];
          _showStartSuggestions = false;
        } else {
          _endPredictions = [];
          _showEndSuggestions = false;
        }
      });
      return;
    }

    try {
      final apiKey = 'AIzaSyApq25cUgw1k5tyFJVI4Ffd49bhg116rkc';
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
            _showStartSuggestions = predictions.isNotEmpty;
            _showEndSuggestions = false;  // Hide end suggestions
          } else {
            _endPredictions = predictions;
            _showEndSuggestions = predictions.isNotEmpty;
            _showStartSuggestions = false;  // Hide start suggestions
          }
        });
      }
    } catch (e) {
      print('Error searching places: $e');
    }
  }

  Future<void> _selectLocation(Prediction prediction, bool isStart) async {
    // Dismiss suggestions immediately
    setState(() {
      if (isStart) {
        _showStartSuggestions = false;
        _startSearchController.text = prediction.description ?? '';
      } else {
        _showEndSuggestions = false;
        _endSearchController.text = prediction.description ?? '';
      }
    });

    final coords = await fetchCoordinatesFromPlaceName(prediction.description!);
    if (coords != null) {
      setState(() {
        if (isStart) {
          currentPosition = coords;
          _startSearchController.text = prediction.description!;
        } else {
          destinationPosition = coords;
          _endSearchController.text = prediction.description!;
        }
      });
      
      if (currentPosition != null && destinationPosition != null) {
        await _updateRoute();
      }
    }
  }

  Future<void> fetchCurrentLocation() async {
    try {
      bool serviceEnabled = await locationController.serviceEnabled().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          print('Location service check timed out');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location service check timed out. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
          return false;
        },
      );
      
      if (!serviceEnabled) {
        serviceEnabled = await locationController.requestService().timeout(
          Duration(seconds: 10),
          onTimeout: () {
            print('Location service request timed out');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Please enable location services to use this feature.'),
                backgroundColor: Colors.red,
              ),
            );
            return false;
          },
        );
        if (!serviceEnabled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location services are disabled. Please enable GPS in your device settings.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
      }

      PermissionStatus permissionGranted = await locationController.hasPermission().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('Location permission check timed out');
          return PermissionStatus.denied;
        },
      );
      
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await locationController.requestPermission().timeout(
          Duration(seconds: 10),
          onTimeout: () {
            print('Location permission request timed out');
            return PermissionStatus.denied;
          },
        );
        if (permissionGranted != PermissionStatus.granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location permission denied. Please enable location permissions in app settings.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
      }

      LocationData locationData = await locationController.getLocation().timeout(
        Duration(seconds: 15),
        onTimeout: () {
          print('Getting location timed out');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to get your location. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
          throw TimeoutException('Location request timed out');
        },
      );
      
      if (locationData.latitude == null || locationData.longitude == null) {
        print('Invalid location data received');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not determine your location. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      setState(() {
        currentPosition = LatLng(locationData.latitude!, locationData.longitude!);
      });
      
      // Move map camera to current location
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(currentPosition!, 15),
        );
      }

    } catch (e) {
      print('Error fetching current location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: ${e.toString().length > 50 ? e.toString().substring(0, 50) + '...' : e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      final apiKey = 'AIzaSyApq25cUgw1k5tyFJVI4Ffd49bhg116rkc';
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
        'AIzaSyApq25cUgw1k5tyFJVI4Ffd49bhg116rkc',
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

    final apiKey = 'AIzaSyApq25cUgw1k5tyFJVI4Ffd49bhg116rkc';
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

  Future<void> _loadSavedMode() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentMode = RideMode.values[prefs.getInt('ride_mode') ?? 0];
    });
  }

  Future<bool> _showWelcomeDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.emoji_emotions, color: Colors.blue[700], size: 28),
              SizedBox(width: 10),
              Text(
                'Welcome!',
                style: TextStyle(
                  color: Colors.blue[900],
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ready to start your journey as a ride provider?',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 12),
              Text(
                '• Earn money by giving rides\n• Choose your own schedule\n• Meet new people',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: Text(
                'Not Now',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final userId = FirebaseAuth.instance.currentUser?.uid;
                  if (userId == null) {
                    Navigator.pop(context, false);
                    return;
                  }

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .update({
                    'isRideProvider': true,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  if (!mounted) return;
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Welcome aboard! You can now give rides.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  print('Error updating ride provider status: $e');
                  Navigator.pop(context, false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                "Let's Go!",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _saveMode(RideMode mode) async {
    logger.i('Attempting to switch ride mode to: ${mode.toString()}');

    if (mode == RideMode.give) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        logger.w('Cannot switch to give mode: No authenticated user');
        return;
      }

      try {
        logger.d('Checking ride provider status for user: $userId');
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        
        final isRideProvider = userDoc.data()?['isRideProvider'] ?? false;
        logger.d('User ride provider status: $isRideProvider');
        
        if (!isRideProvider) {
          logger.i('User is not a ride provider, showing welcome dialog');
          final accepted = await _showWelcomeDialog();
          if (!accepted) {
            logger.i('User declined to become ride provider');
            _currentMode = RideMode.take;
            return;
          }
          logger.i('User accepted to become ride provider');
        }

        logger.d('Checking driver verification documents');
        final verificationDoc = await FirebaseFirestore.instance
            .collection('driver_verifications')
            .doc(userId)
            .get();

        if (!verificationDoc.exists) {
          logger.w('No verification documents found for user');
          _showVerificationAlert(
            'Driver Verification Required',
            'Please submit your documents in the profile page to start giving rides.',
            'Go to Profile'
          );
          return;
        }

        final data = verificationDoc.data()!;
        logger.d('Verification status: ${data.toString()}');
        final submissionStatus = data['submissionStatus'] as String?;
        final isLicenseValid = data['isLicenseValid'] as bool? ?? false;
        final isPanValid = data['isPanValid'] as bool? ?? false;
        final isOverallDataValid = data['isOverallDataValid'] as bool? ?? false;
        final submittedAt = data['submittedAt'];

        if (submissionStatus == 'pending' && submittedAt == null) {
          _showVerificationAlert(
            'Documents Not Submitted',
            'Please submit your verification documents in the profile page to start giving rides.',
            'Go to Profile'
          );
          return;
        }

        if (!isOverallDataValid) {
          if (submissionStatus == 'pending' && submittedAt != null) {
            _showVerificationAlert(
              'Verification Pending',
              'Your documents are under review. We\'ll notify you once verified.',
              'OK'
            );
            return;
          }

          List<String> invalidDocs = [];
          if (!isLicenseValid) invalidDocs.add('Driving License');
          if (!isPanValid) invalidDocs.add('PAN Card');

          if (invalidDocs.isEmpty) {
            _showVerificationAlert(
              'Verification Failed',
              'None of your documents were accepted. Please resubmit in profile page.',
              'Go to Profile'
            );
          } else {
            _showVerificationAlert(
              'Invalid Documents',
              'The following documents were not accepted: ${invalidDocs.join(", ")}. Please resubmit in profile page.',
              'Go to Profile'
            );
          }
          return;
        }
      } catch (e, stackTrace) {
        logger.e('Error checking driver status', error: e, stackTrace: stackTrace);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking status. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // If all checks pass or if switching to take ride mode
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ride_mode', mode.index);
      await prefs.setString('ride_mode', mode == RideMode.give ? 'give' : 'take');
      
      logger.i('Successfully switched ride mode to: ${mode.toString()}');
      logger.d('Saved preferences - mode.index: ${mode.index}, mode string: ${mode == RideMode.give ? 'give' : 'take'}');

      setState(() {
        _currentMode = mode;
      });
    } catch (e, stackTrace) {
      logger.e('Error saving ride mode preferences', error: e, stackTrace: stackTrace);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving ride mode. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showVerificationAlert(String title, String message, String buttonText) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: Colors.blue[900],
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                buttonText,
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                if (buttonText == 'Go to Profile') {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => MainNavigation(initialIndex: 3),
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

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      await _updateLocation();
    });
  }

  Future<void> _updateLocation() async {
    try {
      LocationData locationData = await _location.getLocation();
      
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'location': GeoPoint(
          locationData.latitude!,
          locationData.longitude!,
        ),
        'last_updated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(  // Add WillPopScope to handle back button
      onWillPop: () async {
        if (isSuggestionsVisible) {
          setState(() {
            _showStartSuggestions = false;
            _showEndSuggestions = false;
          });
          return false;  // Don't close the app
        }
        return true;  // Allow app to close
      },
      child: GestureDetector(
        onTap: () {
          // Dismiss keyboard and suggestions when tapping outside
          FocusScope.of(context).unfocus();
          setState(() {
            _showStartSuggestions = false;
            _showEndSuggestions = false;
          });
        },
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LaneMate',
                  style: TextStyle(
                    color: Colors.blue[900],
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildModeButton(
                        title: 'Take a Ride',
                        mode: RideMode.take,
                        icon: Icons.directions_car_filled,
                      ),
                      _buildModeButton(
                        title: 'Give a Ride',
                        mode: RideMode.give,
                        icon: Icons.airline_seat_recline_normal,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            toolbarHeight: 100,
          ),
          body: Column(
            children: [
              // Search inputs container
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Start Location TextField
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: TextField(
                        controller: _startSearchController,
                        focusNode: _startFocusNode,
                        decoration: InputDecoration(
                          prefixIcon: InkWell(
                            onTap: () async {
                              // Show loading indicator
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Getting your current location...'),
                                    ],
                                  ),
                                  duration: Duration(seconds: 2),
                                  backgroundColor: Colors.blue,
                                ),
                              );
                              
                              // Get current location
                              await fetchCurrentLocation();
                              
                              if (currentPosition != null) {
                                // Get address for the current location
                                final address = await getAddressFromLatLng(currentPosition!);
                                
                                // Update text field with current address
                                setState(() {
                                  _startSearchController.text = address ?? 'Current Location';
                                });
                                
                                // If destination is already set, update route
                                if (destinationPosition != null) {
                                  await _updateRoute();
                                }
                              }
                            },
                            child: Icon(Icons.my_location, color: Colors.blue[700]),
                          ),
                          hintText: 'Start Location',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (value) => _searchPlaces(value, true),
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    
                    // Destination TextField
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: TextField(
                        controller: _endSearchController,
                        focusNode: _endFocusNode,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.location_on, color: Colors.red[700]),
                          hintText: 'Where to?',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (value) => _searchPlaces(value, false),
                      ),
                    ),

                    // Show ETA and distance if available
                    if (eta != null && distance != null)
                      Container(
                        margin: EdgeInsets.only(top: 16),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[50]!, Colors.blue[100]!],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildInfoItem(Icons.timer, eta!),
                            Container(height: 24, width: 1, color: Colors.blue[200]),
                            _buildInfoItem(Icons.directions_car, distance!),
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
                    // Single suggestions container that handles both start and end
                    if (_showStartSuggestions || _showEndSuggestions)
                      Positioned(
                        top: 0,
                        left: 16,
                        right: 16,
                        child: Container(
                          margin: EdgeInsets.only(top: 8),
                          child: _buildSuggestionsContainer(
                            _showStartSuggestions ? _startPredictions : _endPredictions,
                            _showStartSuggestions,
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VehicleSelectionPage(
                                  startPoint: currentPosition!,
                                  destination: destinationPosition!,
                                  startAddress: _startSearchController.text,
                                  destinationAddress: _endSearchController.text,
                                  distance: distance ?? 'Unknown',
                                  duration: eta ?? 'Unknown',
                                ),
                              ),
                            );
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
                    // SOS button
                    _buildSosButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required String title,
    required RideMode mode,
    required IconData icon,
  }) {
    final isSelected = _currentMode == mode;
    return GestureDetector(
      onTap: () => _saveMode(mode),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[700] : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.blue[700],
            ),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.blue[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSosButton() {
    return Positioned(
      top: 100,
      right: 16,
      child: FloatingActionButton(
        backgroundColor: Colors.red,
        child: Icon(Icons.emergency, color: Colors.white),
        onPressed: () async {
          try {
            final Uri telUri = Uri(
              scheme: 'tel',
              path: '112',
            );
            
            if (await canLaunchUrl(telUri)) {
              await launchUrl(telUri, mode: LaunchMode.externalApplication);
            } else {
              // Fallback for when URL launcher fails
              final phoneNumber = '112';
              final fallbackUri = Uri.parse('tel:$phoneNumber');
              if (await canLaunchUrl(fallbackUri)) {
                await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
              } else {
                throw 'Could not launch emergency number';
              }
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error launching emergency call: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildSuggestionsContainer(List<Prediction> predictions, bool isStart) {
    return Container(
      margin: EdgeInsets.only(top: 4),
      constraints: BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: predictions.length,
        itemBuilder: (context, index) {
          final prediction = predictions[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _selectLocation(prediction, isStart),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      isStart ? Icons.my_location : Icons.location_on,
                      color: isStart ? Colors.blue[700] : Colors.red[700],
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prediction.structuredFormatting?.mainText ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          if (prediction.structuredFormatting?.secondaryText != null)
                            Text(
                              prediction.structuredFormatting!.secondaryText!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue[700], size: 20),
        SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: Colors.blue[900],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
