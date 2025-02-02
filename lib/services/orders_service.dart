import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrdersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger();

  Future<List<Map<String, dynamic>>> fetchOrdersByStatus(String status) async {
    try {
      _logger.i("Fetching orders with status: $status");
      
      QuerySnapshot snapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: status)
          .get();

      final orders = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
      
      // Log each order's address
      for (var order in orders) {
        _logger.i("Order ID: ${order['itemId']} - Address: ${order['address']}");
        
        // Log additional location details if they exist
        if (order['location'] != null) {
          _logger.i("Location details for order ${order['itemId']}:");
          _logger.i("Latitude: ${order['location']['latitude']}");
          _logger.i("Longitude: ${order['location']['longitude']}");
        }
      }

      _logger.i("Successfully fetched ${orders.length} orders");
      return orders;
    } catch (e, stackTrace) {
      _logger.e("Error fetching orders", error: e, stackTrace: stackTrace);
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchOrdersByItemId(String itemId) async {
    try {
      _logger.i("Fetching order with itemId: $itemId");
      
      DocumentSnapshot doc = await _firestore
          .collection('orders')
          .doc(itemId)
          .get();

      if (doc.exists) {
        final order = doc.data() as Map<String, dynamic>;
        _logger.i("Found order - Address: ${order['address']}");
        
        // Log location details if they exist
        if (order['location'] != null) {
          _logger.i("Location details:");
          _logger.i("Latitude: ${order['location']['latitude']}");
          _logger.i("Longitude: ${order['location']['longitude']}");
        }
        
        return order;
      } else {
        _logger.w("No order found with itemId: $itemId");
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e("Error fetching order by itemId", error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Stream<List<Map<String, dynamic>>> streamOrdersByStatus(
    String status, {
    required bool isDriver,
  }) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    Query query = _firestore.collection('ride_orders');

    if (isDriver) {
      switch (status) {
        case 'pending':
          // Available rides (no rider assigned and not expired/cancelled)
          query = query.where('status', isEqualTo: status)
                      .where('rider_id', isNull: true)
                      .where('is_cancelled', isEqualTo: false);
          break;
        case 'accepted':
          // Rides accepted by this driver
          query = query.where('rider_id', isEqualTo: userId)
                      .where('status', whereIn: ['accepted', 'in_transit']);
          break;
        case 'completed':
          // Rides completed by this driver
          query = query.where('rider_id', isEqualTo: userId)
                      .where('status', isEqualTo: 'completed');
          break;
      }
    } else {
      // Passenger's rides
      query = query.where('user_id', isEqualTo: userId)
                  .where('status', isEqualTo: status);
    }

    // Add timestamp ordering
    query = query.orderBy('request_time', descending: true);

    _logger.i('Streaming orders with status: $status, isDriver: $isDriver');

    return query.snapshots().map((snapshot) {
      final orders = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      _logger.i('Found ${orders.length} orders');
      return orders;
    });
  }

  Future<bool> acceptRide(String orderId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      // Run in transaction to ensure ride is still available
      bool success = false;
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection('ride_orders').doc(orderId);
        final doc = await transaction.get(docRef);

        if (!doc.exists) throw 'Ride not found';
        final data = doc.data()!;

        if (data['status'] != 'pending') throw 'Ride no longer available';
        if (data['rider_id'] != null) throw 'Ride already accepted';

        transaction.update(docRef, {
          'status': 'accepted',
          'rider_id': userId,
          'accept_time': FieldValue.serverTimestamp(),
        });

        success = true;
      });

      return success;
    } catch (e) {
      _logger.e('Error accepting ride: $e');
      return false;
    }
  }
}
