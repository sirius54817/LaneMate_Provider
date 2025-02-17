import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:ecub_delivery/services/wallet_service.dart';

class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key});

  @override
  State<EarningsPage> createState() => _Earningsklu_pagetate();
}

class _Earningsklu_pagetate extends State<EarningsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _deliveryHistory = [];
  double _totalEarnings = 0;
  StreamSubscription? _agentSubscription;
  final WalletService _walletService = WalletService();
  double _walletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _setupAgentStream();
    _walletService.getWalletStream().listen((snapshot) {
      if (mounted) {
        setState(() {
          final data = snapshot.data() as Map<String, dynamic>?;
          _walletBalance = (data?['balance'] ?? 0.0).toDouble();
        });
      }
    });
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
                content: Text('Error loading rides history: $error'),
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
            content: Text('Failed to load rides history: $e'),
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
        backgroundColor: Colors.green.shade50,
        toolbarHeight: 80,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Text(
              'LaneMate',
              style: TextStyle(
                foreground: Paint()
                  ..shader = LinearGradient(
                    colors: [
                      Colors.green.shade800,
                      Colors.green.shade600,
                    ],
                  ).createShader(Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              ' • ',
              style: TextStyle(
                color: Colors.green.shade300,
                fontSize: 24,
              ),
            ),
            Text(
              'Earnings',
              style: TextStyle(
                foreground: Paint()
                  ..shader = LinearGradient(
                    colors: [
                      Colors.green.shade700,
                      Colors.green.shade500,
                    ],
                  ).createShader(Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Colors.green.shade700,
            ),
            onPressed: () async {
              setState(() => _isLoading = true);
              await _agentSubscription?.cancel();
              _setupAgentStream();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.refresh, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Refreshing earnings...'),
                    ],
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: Colors.green.shade700,
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          SizedBox(width: 8),
        ],
      ),
      backgroundColor: Colors.green.shade50,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Colors.green.shade700,
              ),
            )
          : Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  // Enhanced Earnings Summary Card
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.green.shade400,
                          Colors.green.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.shade200.withOpacity(0.5),
                          spreadRadius: 2,
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -30,
                          right: -30,
                          child: Icon(
                            Icons.account_balance_wallet,
                            size: 150,
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.payments,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Total Earnings',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            Text(
                              '₹${_totalEarnings.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  // Wallet Section
                  _buildWalletSection(),
                  SizedBox(height: 24),
                  // Enhanced Rides History Section
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            offset: Offset(0, 4),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.history,
                                  color: Colors.green.shade700,
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Rides History',
                                style: TextStyle(
                                  color: Colors.green.shade900,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          Expanded(
                            child: _deliveryHistory.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.history,
                                          size: 80,
                                          color: Colors.green.shade200,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'No rides yet',
                                          style: TextStyle(
                                            color: Colors.green.shade900,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          'Your completed rides will appear here',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    physics: BouncingScrollPhysics(),
                                    itemCount: _deliveryHistory.length,
                                    itemBuilder: (context, index) {
                                      return _buildDeliveryCard(_deliveryHistory[index]);
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
    final orderType = delivery['type'] ?? 'food';

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            orderType == 'medical' 
                ? Colors.blue.shade50 
                : Colors.green.shade50,
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: orderType == 'medical' 
                ? Colors.blue.shade100.withOpacity(0.3)
                : Colors.green.shade100.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            orderType == 'medical' ? Icons.medical_services : Icons.delivery_dining,
            color: orderType == 'medical' ? Colors.blue.shade700 : Colors.green.shade700,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Text(
              '₹${delivery['amount']}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade900,
                fontSize: 20,
              ),
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: orderType == 'medical' 
                    ? Colors.blue.shade50 
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                orderType.toUpperCase(),
                style: TextStyle(
                  color: orderType == 'medical' 
                      ? Colors.blue.shade700 
                      : Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8),
            Text(
              date,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            Text(
              delivery['location'] ?? 'Location not available',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (delivery['distance'] != null)
              Text(
                'Distance: ${delivery['distance']}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletSection() {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wallet Balance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
          SizedBox(height: 8),
          Text(
            '₹${_walletBalance.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showAddMoneyDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Add Money'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showWithdrawDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Withdraw'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddMoneyDialog() {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Money to Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹',
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Transaction fee: ₹${WalletService.TRANSACTION_FEE}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                _walletService.addMoney(amount);
                Navigator.pop(context);
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog() {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Withdraw Money'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹',
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Transaction fee: ₹${WalletService.TRANSACTION_FEE}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                try {
                  await _walletService.withdrawMoney(amount);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Withdrawal request submitted')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            child: Text('Withdraw'),
          ),
        ],
      ),
    );
  }
}
