import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key});

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _deliveryHistory = [];
  double _totalEarnings = 0;
  StreamSubscription? _agentSubscription;

  @override
  void initState() {
    super.initState();
    _setupAgentStream();
  }

  @override
  void dispose() {
    _agentSubscription?.cancel();
    super.dispose();
  }

  void _setupAgentStream() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.email == null) {
        throw 'No authenticated user found';
      }

      // Create a stream for the agent document
      final Stream<QuerySnapshot> agentStream = FirebaseFirestore.instance
          .collection('delivery_agent')
          .where('email', isEqualTo: currentUser!.email)
          .snapshots();

      _agentSubscription = agentStream.listen(
        (snapshot) {
          if (snapshot.docs.isEmpty) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _deliveryHistory = [];
                _totalEarnings = 0;
              });
            }
            return;
          }

          final agentData = snapshot.docs.first.data() as Map<String, dynamic>;
          
          if (mounted) {
            setState(() {
              _deliveryHistory = List<Map<String, dynamic>>.from(
                agentData['delivery_history'] ?? []
              )..sort((a, b) => (b['timestamp'] as Timestamp)
                  .compareTo(a['timestamp'] as Timestamp)); // Sort by newest first
              _totalEarnings = (agentData['salary'] ?? 0).toDouble();
              _isLoading = false;
            });
          }
        },
        onError: (error) {
          print('Error in agent stream: $error');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading delivery history: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
    } catch (e) {
      print('Error setting up agent stream: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load delivery history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        toolbarHeight: 80,
        elevation: 0,
        automaticallyImplyLeading: false,
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
              'Earnings',
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          // Add refresh button
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Colors.blue[700],
            ),
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });
              
              // Cancel existing subscription
              await _agentSubscription?.cancel();
              
              // Setup stream again
              _setupAgentStream();
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Refreshing earnings data...'),
                  duration: Duration(seconds: 1),
                  backgroundColor: Colors.blue,
                ),
              );
            },
          ),
          SizedBox(width: 8),  // Add some padding
        ],
      ),
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(
              color: Colors.blue[700],
            ))
          : Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  // Earnings Summary Card
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue[50]!,
                          Colors.blue[100]!,
                          Colors.blue[200]!.withOpacity(0.5),
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue[200]!.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -20,
                          right: -20,
                          child: Icon(
                            Icons.account_balance_wallet,
                            size: 120,
                            color: Colors.blue[200]!.withOpacity(0.3),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.payments, color: Colors.blue[700]),
                                SizedBox(width: 8),
                                Text(
                                  'Total Earnings',
                                  style: TextStyle(
                                    color: Colors.blue[900],
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 15),
                            Text(
                              '₹${_totalEarnings.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  // Delivery History
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey[300]!,
                            offset: Offset(0, 4),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: Colors.grey[200]!,
                            offset: Offset(0, 2),
                            blurRadius: 6,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.history, color: Colors.blue[700]),
                              SizedBox(width: 8),
                              Text(
                                'Delivery History',
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 15),
                          Expanded(
                            child: _deliveryHistory.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.history,
                                          size: 64,
                                          color: Colors.blue[200],
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'No delivery history yet',
                                          style: TextStyle(
                                            color: Colors.blue[900],
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _deliveryHistory.length,
                                    itemBuilder: (context, index) {
                                      final delivery = _deliveryHistory[index];
                                      return _buildDeliveryCard(delivery);
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDeliveryCard(Map<String, dynamic> delivery) {
    final timestamp = delivery['timestamp'] as Timestamp;
    final date = DateFormat('MMM dd, yyyy hh:mm a').format(timestamp.toDate());
    final orderType = delivery['type'] ?? 'food';  // Default to food if not specified

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 0,
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
          boxShadow: [
            BoxShadow(
              color: Colors.grey[300]!,
              offset: Offset(0, 3),
              blurRadius: 8,
              spreadRadius: -2,
            ),
            BoxShadow(
              color: Colors.grey[200]!,
              offset: Offset(0, 1),
              blurRadius: 4,
              spreadRadius: -1,
            ),
          ],
        ),
        child: ListTile(
          contentPadding: EdgeInsets.all(16),
          leading: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: orderType == 'medical' ? Colors.blue[50] : Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: orderType == 'medical' ? Colors.blue[100]! : Colors.green[100]!,
                width: 1,
              ),
            ),
            child: Icon(
              orderType == 'medical' ? Icons.medical_services : Icons.delivery_dining,
              color: orderType == 'medical' ? Colors.blue[700] : Colors.green[700],
              size: 20,
            ),
          ),
          title: Text(
            '₹${delivery['amount']}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
              fontSize: 18,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4),
              Text(date),
              Text(
                delivery['location'] ?? 'Location not available',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              if (delivery['distance'] != null)
                Text(
                  'Distance: ${delivery['distance']}',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              Text(
                'Type: ${orderType.toUpperCase()}',
                style: TextStyle(
                  color: orderType == 'medical' ? Colors.blue[700] : Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
