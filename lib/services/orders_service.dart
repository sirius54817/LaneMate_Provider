import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class OrdersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
}
