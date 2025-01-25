import 'package:flutter/material.dart';
import 'package:ecub_delivery/pages/home.dart';
import 'package:ecub_delivery/pages/Orders.dart';
import 'package:ecub_delivery/pages/Earnings.dart';
import 'package:ecub_delivery/pages/profile.dart';
import 'dart:async';
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

final logger = Logger();

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  Timer? _locationUpdateTimer;
  final Location _location = Location();
  bool _isUpdatingLocation = false;  // Add this flag
  
  final List<Widget> _pages = [
    HomeScreen(),
    OrdersPage(),
    EarningsPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      await _setupLocationUpdates();
      // Do initial location update
      await _updateAgentLocation();
    } catch (e) {
      debugPrint('Error initializing location: $e');
    }
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

      // Configure location settings
      await _location.changeSettings(
        accuracy: LocationAccuracy.balanced,
        interval: 5000,  // Changed from 30000 to 5000 milliseconds (5 seconds)
        distanceFilter: 10,  // Reduced from 30 to 10 meters for more frequent updates
      );

      // Start periodic updates
      _locationUpdateTimer?.cancel();
      _locationUpdateTimer = Timer.periodic(
        Duration(seconds: 5),  // Changed from 30 to 5 seconds
        (timer) async {
          if (!_isUpdatingLocation) {
            await _updateAgentLocation();
          }
        },
      );
    } catch (e) {
      debugPrint('Error setting up location updates: $e');
    }
  }

  Future<void> _updateAgentLocation() async {
    if (_isUpdatingLocation) return;
    
    try {
      _isUpdatingLocation = true;
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('No user logged in');
        return;
      }

      LocationData? locationData;
      try {
        locationData = await _location.getLocation().timeout(
          Duration(seconds: 10),  // Reduced timeout
        );
      } catch (e) {
        debugPrint('Error getting location: $e');
        return;
      }

      if (locationData.latitude == null || locationData.longitude == null) {
        debugPrint('Invalid location data received');
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      int updatedOrders = 0;
      
      // Update food orders
      try {
        final foodOrders = await FirebaseFirestore.instance
            .collection('orders')
            .where('del_agent', isEqualTo: currentUser.uid)
            .where('status', isEqualTo: 'in_transit')
            .get();

        for (var doc in foodOrders.docs) {
          batch.update(doc.reference, {
            'agent_location': GeoPoint(
              locationData.latitude!,
              locationData.longitude!,
            ),
            'last_location_update': FieldValue.serverTimestamp(),
          });
          updatedOrders++;
        }
      } catch (e) {
        debugPrint('Error updating food orders: $e');
      }

      // Update medical orders
      try {
        logger.i("Starting medical orders location update");
        final medicalOrders = await FirebaseFirestore.instance
            .collection('me_orders')
            .get();

        logger.d("Found ${medicalOrders.docs.length} medical order documents");

        for (var doc in medicalOrders.docs) {
          try {
            logger.d("Processing medical order for customer: ${doc.id}");
            
            // Get all orders for this customer
            final ordersSnapshot = await FirebaseFirestore.instance
                .collection('me_orders')
                .doc(doc.id)
                .collection('orders')
                .where('del_agent', isEqualTo: currentUser.uid)
                .where('order_status', isEqualTo: 'in_transit')
                .get();

            // Process each order for this customer
            for (var orderDoc in ordersSnapshot.docs) {
              try {
                logger.d("Processing order ${orderDoc.id} for customer ${doc.id}");
                
                final orderData = orderDoc.data();
                logger.d("Order data: $orderData");

                // Update location for this order
                batch.update(orderDoc.reference, {
                  'agent_location': GeoPoint(
                    locationData.latitude!,
                    locationData.longitude!,
                  ),
                  'last_location_update': FieldValue.serverTimestamp(),
                });
                
                updatedOrders++;
                logger.i("Added medical order ${orderDoc.id} to batch update");
              } catch (e, stackTrace) {
                logger.e("Error processing order ${orderDoc.id}", error: e, stackTrace: stackTrace);
                continue;
              }
            }
          } catch (e, stackTrace) {
            logger.e("Error processing customer ${doc.id}", error: e, stackTrace: stackTrace);
            continue;
          }
        }

        logger.i("Medical orders processing completed. Added $updatedOrders orders to batch");
      } catch (e, stackTrace) {
        logger.e("Error updating medical orders", error: e, stackTrace: stackTrace);
      }

      if (updatedOrders > 0) {
        try {
          await batch.commit();
          logger.i('Successfully updated location for $updatedOrders orders');
        } catch (e, stackTrace) {
          logger.e('Error committing batch update', error: e, stackTrace: stackTrace);
        }
      }

    } catch (e) {
      debugPrint('Error in location update: $e');
    } finally {
      _isUpdatingLocation = false;
    }
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    bool isSelected = _selectedIndex == index;
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: isSelected ? 20 : 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue[50] : Colors.transparent,
        borderRadius: BorderRadius.circular(25),
        border: isSelected ? Border.all(
          color: Colors.blue[200]!.withOpacity(0.5),
          width: 1,
        ) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            duration: Duration(milliseconds: 200),
            scale: isSelected ? 1.1 : 1.0,
            curve: Curves.easeOutCubic,
            child: Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? Colors.blue[700] : Colors.grey[600],
              size: 24,
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Row(
                children: [
                  if (isSelected) ...[
                    SizedBox(width: 10),
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Container(
              height: 70,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  InkWell(
                    onTap: () => _onItemTapped(0),
                    borderRadius: BorderRadius.circular(20),
                    child: _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
                  ),
                  InkWell(
                    onTap: () => _onItemTapped(1),
                    borderRadius: BorderRadius.circular(20),
                    child: _buildNavItem(1, Icons.list_alt_outlined, Icons.list_alt, 'Orders'),
                  ),
                  InkWell(
                    onTap: () => _onItemTapped(2),
                    borderRadius: BorderRadius.circular(20),
                    child: _buildNavItem(2, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Earnings'),
                  ),
                  InkWell(
                    onTap: () => _onItemTapped(3),
                    borderRadius: BorderRadius.circular(20),
                    child: _buildNavItem(3, Icons.person_outline, Icons.person, 'Profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LocationUpdateManager {
  static final LocationUpdateManager _instance = LocationUpdateManager._internal();
  factory LocationUpdateManager() => _instance;
  LocationUpdateManager._internal();

  Timer? _locationUpdateTimer;
  final Location _location = Location();
  bool _isUpdatingLocation = false;
  
  void startLocationUpdates() async {
    await _setupLocationUpdates();
  }

  void stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    _isUpdatingLocation = false;
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

      // Configure location settings
      await _location.changeSettings(
        accuracy: LocationAccuracy.balanced,
        interval: 5000,  // Changed from 30000 to 5000 milliseconds (5 seconds)
        distanceFilter: 10,  // Reduced from 30 to 10 meters for more frequent updates
      );

      // Start periodic updates
      _locationUpdateTimer?.cancel();
      _locationUpdateTimer = Timer.periodic(
        Duration(seconds: 5),  // Changed from 30 to 5 seconds
        (timer) async {
          if (!_isUpdatingLocation) {
            await _updateAgentLocation();
          }
        },
      );
    } catch (e) {
      debugPrint('Error setting up location updates: $e');
    }
  }

  Future<void> _updateAgentLocation() async {
    if (_isUpdatingLocation) return;
    
    try {
      _isUpdatingLocation = true;
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('No user logged in');
        return;
      }

      LocationData? locationData;
      try {
        locationData = await _location.getLocation().timeout(
          Duration(seconds: 10),  // Reduced timeout
        );
      } catch (e) {
        debugPrint('Error getting location: $e');
        return;
      }

      if (locationData.latitude == null || locationData.longitude == null) {
        debugPrint('Invalid location data received');
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      int updatedOrders = 0;
      
      // Update food orders
      try {
        final foodOrders = await FirebaseFirestore.instance
            .collection('orders')
            .where('del_agent', isEqualTo: currentUser.uid)
            .where('status', isEqualTo: 'in_transit')
            .get();

        for (var doc in foodOrders.docs) {
          batch.update(doc.reference, {
            'agent_location': GeoPoint(
              locationData.latitude!,
              locationData.longitude!,
            ),
            'last_location_update': FieldValue.serverTimestamp(),
          });
          updatedOrders++;
        }
      } catch (e) {
        debugPrint('Error updating food orders: $e');
      }

      // Update medical orders
      try {
        logger.i("Starting medical orders location update");
        final medicalOrders = await FirebaseFirestore.instance
            .collection('me_orders')
            .get();

        logger.d("Found ${medicalOrders.docs.length} medical order documents");

        for (var doc in medicalOrders.docs) {
          try {
            logger.d("Processing medical order for customer: ${doc.id}");
            
            // Get all orders for this customer
            final ordersSnapshot = await FirebaseFirestore.instance
                .collection('me_orders')
                .doc(doc.id)
                .collection('orders')
                .where('del_agent', isEqualTo: currentUser.uid)
                .where('order_status', isEqualTo: 'in_transit')
                .get();

            // Process each order for this customer
            for (var orderDoc in ordersSnapshot.docs) {
              try {
                logger.d("Processing order ${orderDoc.id} for customer ${doc.id}");
                
                final orderData = orderDoc.data();
                logger.d("Order data: $orderData");

                // Update location for this order
                batch.update(orderDoc.reference, {
                  'agent_location': GeoPoint(
                    locationData.latitude!,
                    locationData.longitude!,
                  ),
                  'last_location_update': FieldValue.serverTimestamp(),
                });
                
                updatedOrders++;
                logger.i("Added medical order ${orderDoc.id} to batch update");
              } catch (e, stackTrace) {
                logger.e("Error processing order ${orderDoc.id}", error: e, stackTrace: stackTrace);
                continue;
              }
            }
          } catch (e, stackTrace) {
            logger.e("Error processing customer ${doc.id}", error: e, stackTrace: stackTrace);
            continue;
          }
        }

        logger.i("Medical orders processing completed. Added $updatedOrders orders to batch");
      } catch (e, stackTrace) {
        logger.e("Error updating medical orders", error: e, stackTrace: stackTrace);
      }

      if (updatedOrders > 0) {
        try {
          await batch.commit();
          logger.i('Successfully updated location for $updatedOrders orders');
        } catch (e, stackTrace) {
          logger.e('Error committing batch update', error: e, stackTrace: stackTrace);
        }
      }

    } catch (e) {
      debugPrint('Error in location update: $e');
    } finally {
      _isUpdatingLocation = false;
    }
  }
}