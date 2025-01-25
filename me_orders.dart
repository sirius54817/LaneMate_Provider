import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecub_s1_v2/translation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as dev;
import 'package:ecub_s1_v2/service_page/medical_equipment/MeFeedbackDialog.dart';
import 'package:logger/logger.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

final logger = Logger();

class MeOrders extends StatefulWidget {
  const MeOrders({super.key});

  @override
  State<MeOrders> createState() => _MeOrdersState();
}

class _MeOrdersState extends State<MeOrders> with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  late TabController _tabController;

  @override 
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> fetchBuyOrders() {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user?.email != null) {
        dev.log('Fetching buy orders for user: ${user?.email}');
        return FirebaseFirestore.instance
            .collection('me_orders')
            .doc(user?.email)
            .collection('orders')
            .orderBy('order_time', descending: true)
            .snapshots();
      }
      dev.log('No user logged in', level: 1);
      return Stream.empty();
    } catch (e, stack) {
      dev.log('Error in fetchBuyOrders', error: e, stackTrace: stack);
      return Stream.empty();
    }
  }

  Stream<QuerySnapshot> fetchRentOrders() {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user?.email != null) {
        dev.log('Fetching rent orders for user: ${user?.email}');
        return FirebaseFirestore.instance
            .collection('me_orders_rent')
            .doc(user?.email)
            .collection('orders')
            .orderBy('order_time', descending: true)
            .snapshots();
      }
      dev.log('No user logged in', level: 1);
      return Stream.empty();
    } catch (e, stack) {
      dev.log('Error in fetchRentOrders', error: e, stackTrace: stack);
      return Stream.empty();
    }
  }

  Future<void> _launchMaps(double destLat, double destLng) async {
    try {
      final url = 'google.navigation:q=$destLat,$destLng';
      final uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        MapsLauncher.launchCoordinates(destLat, destLng);
      }
    } catch (e) {
      print('Error launching maps: $e');
    }
  }

  Future<void> _cancelOrder(String orderId, bool isRentOrder, Map<String, dynamic> orderData) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) return;

      // Show confirmation dialog
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Cancel Order'),
          content: Text('Are you sure you want to cancel this order?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: Text('Yes'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Get the collection reference based on order type
      final CollectionReference ordersCollection = FirebaseFirestore.instance
          .collection(isRentOrder ? 'me_orders_rent' : 'me_orders')
          .doc(user?.email)
          .collection('orders');

      // Update the order status
      await ordersCollection.doc(orderId).update({
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order cancelled successfully')),
      );
    } catch (e) {
      dev.log('Error cancelling order', error: e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel order: ${e.toString()}')),
      );
    }
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    
    switch(status.toLowerCase()) {
      case 'cancelled':
        backgroundColor = Colors.red[50]!;
        textColor = Colors.red;
        break;
      case 'delivered':
        backgroundColor = Colors.green[50]!;
        textColor = Colors.green;
        break;
      case 'processing':
        backgroundColor = Colors.blue[50]!;
        textColor = Colors.blue;
        break;
      default:
        backgroundColor = Colors.grey[50]!;
        textColor = Colors.grey[700]!;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Orders'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Buy Orders'),
            Tab(text: 'Rent Orders'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBuyOrders(),
          _buildRentOrders(),
        ],
      ),
    );
  }

  Widget _buildBuyOrders() {
    return StreamBuilder<QuerySnapshot>(
      stream: fetchBuyOrders(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          dev.log('Error fetching buy orders: ${snapshot.error}', error: snapshot.error);
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No buy orders found'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            try {
              final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              dev.log('Buy order data: $data');
              
              final orderTime = data['order_time'] != null 
                ? DateTime.parse(data['order_time'])
                : DateTime.now();
                
              // Safely handle order summary
              Map<String, dynamic> orderSummary = {};
              if (data['order_summary'] != null) {
                try {
                  orderSummary = Map<String, dynamic>.from(data['order_summary']);
                } catch (e) {
                  dev.log('Error parsing order summary: $e', error: e);
                }
              }
              
              return Card(
                margin: EdgeInsets.all(8),
                child: ExpansionTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text('Order #${data['order_id'] ?? index + 1}'),
                      ),
                      _buildStatusBadge(data['status'] ?? 'Processing'),
                    ],
                  ),
                  subtitle: Text(
                    'Date: ${DateFormat('MMM dd, yyyy hh:mm a').format(orderTime)}',
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Amount: ₹${data['totalPrice']?.toStringAsFixed(2) ?? '0.00'}'),
                          Text('Payment Status: ${data['payment_status'] ?? 'Unknown'}'),
                          Text('Payment ID: ${data['payment_id'] ?? 'Pending'}'),
                          if (data['status']?.toLowerCase() != 'cancelled') ...[
                            SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: () => _cancelOrder(
                                snapshot.data!.docs[index].id,
                                false,
                                data,
                              ),
                              icon: Icon(Icons.cancel, color: Colors.red),
                              label: Text('Cancel Order'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[50],
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ],
                          SizedBox(height: 10),
                          Text('Order Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                          if (orderSummary.isNotEmpty) ...[
                            ...orderSummary.entries.map((entry) {
                              final item = entry.value as Map<String, dynamic>;
                              return ListTile(
                                title: Text(item['name']?.toString() ?? 'Unknown Item'),
                                subtitle: Text(
                                  'Store: ${item['storeName'] ?? 'Unknown Store'}\n'
                                  'Quantity: ${item['quantity'] ?? 1}'
                                ),
                              );
                            }).toList(),
                          ] else
                            Text('No items found'),
                          if (data['status']?.toLowerCase() != 'cancelled') ...[
                            SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: () => _launchMaps(9.5636, 77.6822),
                              icon: Icon(Icons.location_on),
                              label: Text('Track Order'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            } catch (e, stack) {
              dev.log('Error rendering buy order', error: e, stackTrace: stack);
              return Card(
                child: ListTile(
                  title: Text('Error displaying order'),
                  subtitle: Text(e.toString()),
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildRentOrders() {
    return StreamBuilder<QuerySnapshot>(
      stream: fetchRentOrders(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          dev.log('Error fetching rent orders: ${snapshot.error}', error: snapshot.error);
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No rent orders found'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            try {
              final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              dev.log('Rent order data: $data');
              
              final orderTime = data['order_time'] != null 
                ? DateTime.parse(data['order_time'])
                : DateTime.now();
                
              // Safely handle order summary
              Map<String, dynamic> orderSummary = {};
              if (data['order_summary'] != null) {
                try {
                  orderSummary = Map<String, dynamic>.from(data['order_summary']);
                } catch (e) {
                  dev.log('Error parsing order summary: $e', error: e);
                }
              }
              
              return Card(
                margin: EdgeInsets.all(8),
                child: ExpansionTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text('Rent Order #${data['order_id'] ?? index + 1}'),
                      ),
                      _buildStatusBadge(data['status'] ?? 'Processing'),
                    ],
                  ),
                  subtitle: Text(
                    'Date: ${DateFormat('MMM dd, yyyy hh:mm a').format(orderTime)}',
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Rent: ₹${data['totalPrice']?.toStringAsFixed(2) ?? '0.00'}'),
                          Text('Payment Status: ${data['payment_status'] ?? 'Unknown'}'),
                          Text('Payment ID: ${data['payment_id'] ?? 'Pending'}'),
                          if (data['delivery_date'] != null)
                            Text('Delivery Date: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(data['delivery_date']))}'),
                          if (data['return_date'] != null)
                            Text('Return Date: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(data['return_date']))}'),
                          if (data['status']?.toLowerCase() != 'cancelled') ...[
                            SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: () => _cancelOrder(
                                snapshot.data!.docs[index].id,
                                true,
                                data,
                              ),
                              icon: Icon(Icons.cancel, color: Colors.red),
                              label: Text('Cancel Order'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[50],
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ],
                          SizedBox(height: 10),
                          Text('Rented Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                          if (orderSummary.isNotEmpty) ...[
                            ...orderSummary.entries.map((entry) {
                              final item = entry.value as Map<String, dynamic>;
                              return ListTile(
                                title: Text(item['name']?.toString() ?? 'Unknown Item'),
                                subtitle: Text(
                                  'Store: ${item['storeName'] ?? 'Unknown Store'}\n'
                                  'Duration: ${item['duration'] ?? 0} ${item['isWeekly'] == true ? 'weeks' : 'months'}\n'
                                  'Quantity: ${item['quantity'] ?? 1}'
                                ),
                              );
                            }).toList(),
                          ] else
                            Text('No items found'),
                          if (data['status']?.toLowerCase() != 'cancelled') ...[
                            SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: () => _launchMaps(9.5636, 77.6822),
                              icon: Icon(Icons.location_on),
                              label: Text('Track Order'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            } catch (e, stack) {
              dev.log('Error rendering rent order', error: e, stackTrace: stack);
              return Card(
                child: ListTile(
                  title: Text('Error displaying order'),
                  subtitle: Text(e.toString()),
                ),
              );
            }
          },
        );
      },
    );
  }
}

class Item {
  final String name;
  final int quantity;
  final String store;
  final String price;
  Item({
    required this.name,
    required this.quantity,
    required this.store,
    required this.price,
  });
}

class MeOrderCard extends StatelessWidget {
  final Map<String, dynamic> orderData;

  const MeOrderCard({
    Key? key,
    required this.orderData,
  }) : super(key: key);

  Widget _buildReviewSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('me_feedback')
          .where('orderId', isEqualTo: orderData['docId'])
          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.email)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          logger.e('Error loading review', error: snapshot.error);
          return Text('Error loading review');
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          if (orderData['status']?.toLowerCase() == 'delivered') {
            return Column(
              children: [
                SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _showFeedbackDialog(context),
                  icon: Icon(Icons.star_border),
                  label: Text('Rate Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          }
          return SizedBox.shrink();
        }

        final review = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Rating',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          RatingBarIndicator(
                            rating: (review['rating'] ?? 0).toDouble(),
                            itemBuilder: (context, _) => Icon(
                              Icons.star,
                              color: Colors.amber,
                            ),
                            itemCount: 5,
                            itemSize: 16,
                          ),
                          if (review['updatedAt'] != null) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Updated',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showFeedbackDialog(context),
                  icon: Icon(Icons.edit),
                  label: Text('Update'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (review['feedback']?.isNotEmpty ?? false) ...[
              SizedBox(height: 8),
              Text(
                review['feedback'],
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 14,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _showFeedbackDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => MeFeedbackDialog(
        itemId: orderData['itemId'] ?? '',
        itemName: orderData['itemName'] ?? 'Unknown Item',
        providerId: orderData['providerId'] ?? '',
        providerName: orderData['vendor'] ?? 'Unknown Vendor',
        orderId: orderData['docId'] ?? '',
        existingRating: orderData['userRating']?.toDouble(),
        existingFeedback: orderData['userFeedback'],
        isUpdate: orderData['feedbackGiven'] ?? false,
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            orderData['feedbackGiven'] ?? false
                ? 'Feedback updated successfully!'
                : 'Thank you for your feedback!'
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... existing order card content ...

            if (orderData['status']?.toLowerCase() == 'delivered')
              _buildReviewSection(),
          ],
        ),
      ),
    );
  }
}
