import 'package:ecub_delivery/pages/home.dart';
import 'package:ecub_delivery/pages/init.dart';
import 'package:flutter/material.dart';
import 'package:ecub_delivery/services/orders_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw 'No authenticated user found';

      String status;
      switch (_selectedIndex) {
        case 0: // Available orders
          status = 'pending';
          break;
        case 1: // Accepted orders
          status = 'in_transit';
          break;
        case 2: // Completed orders
          status = 'completed';
          break;
        default:
          status = 'pending';
      }

      Query ordersQuery = FirebaseFirestore.instance.collection('orders');
      
      // Add status filter
      ordersQuery = ordersQuery.where('status', isEqualTo: status);
      
      // Add agent filter for accepted and completed orders
      if (_selectedIndex != 0) {
        ordersQuery = ordersQuery.where('del_agent', isEqualTo: currentUser.uid);
      }

      final QuerySnapshot ordersSnapshot = await ordersQuery.get();

      List<Map<String, dynamic>> orders = ordersSnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['docId'] = doc.id;
        return data;
      }).toList();

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
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              order['isVeg'] == true ? Icons.eco : Icons.restaurant,
                              color: Colors.green[700],
                            ),
                          ),
                          title: Text(
                            order['itemName'] ?? 'No Name',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4),
                              Text('Price: ₹${order['itemPrice'] ?? 'N/A'}'),
                              Text('Customer: ${order['userId'] ?? 'N/A'}'),
                              Text('Address: ${order['address'] ?? 'N/A'}'),
                            ],
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          onTap: () {
                            // Convert the order Map to OrdersSam object
                            final orderObj = OrdersSam.fromMap(
                              order,  // This is the Map<String, dynamic>
                              isMedical: false  // Since this is food orders
                            );
                            
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GoogleMapPage(
                                  oder: orderObj,  // Pass the converted OrdersSam object
                                  currentAgentId: FirebaseAuth.instance.currentUser?.uid ?? '',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
