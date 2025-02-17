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
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _deliveryHistory = [];
  double _totalEarnings = 0;
  StreamSubscription? _agentSubscription;
  final WalletService _walletService = WalletService();
  double _walletBalance = 0.0;
  StreamSubscription? _paymentSuccessSubscription;
  bool _showSuccessAnimation = false;
  late TabController _tabController;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupAgentStream();
    _setupWalletListeners();
    _loadTransactions();
  }

  void _setupWalletListeners() {
    // Listen for wallet balance changes
    _walletService.getWalletStream().listen((snapshot) {
      if (mounted) {
        setState(() {
          final data = snapshot.data() as Map<String, dynamic>?;
          _walletBalance = (data?['balance'] ?? 0.0).toDouble();
        });
      }
    });

    // Listen for payment success events
    _paymentSuccessSubscription = _walletService.onPaymentSuccess.listen((data) {
      if (mounted) {
        print('Payment success received: $data'); // Debug log
        _showPaymentSuccessDialog(data['amount']);
      }
    });

    // Listen for payment errors
    _walletService.onPaymentError.listen((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
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

  void _loadTransactions() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    FirebaseFirestore.instance
        .collection('wallets')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (mounted && snapshot.exists) {
        setState(() {
          _transactions = List<Map<String, dynamic>>.from(
              snapshot.data()?['transactions'] ?? [])
            ..sort((a, b) => (b['timestamp'] as Timestamp)
                .compareTo(a['timestamp'] as Timestamp));
        });
      }
    });
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.green.shade700,
          labelColor: Colors.green.shade900,
          unselectedLabelColor: Colors.grey.shade600,
          tabs: [
            Tab(text: 'Wallet'),
            Tab(text: 'Rides'),
          ],
        ),
      ),
      backgroundColor: Colors.green.shade50,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.green.shade700))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildWalletTab(),
                _buildRidesTab(),
              ],
            ),
    );
  }

  Widget _buildWalletTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          // Wallet Balance Card
          _buildWalletCard(),
          SizedBox(height: 24),
          // Transaction History
          Container(
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
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        color: Colors.green.shade700,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Transaction History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_transactions.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No transactions yet',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) =>
                        _buildTransactionItem(_transactions[index]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final isCredit = transaction['type'] == 'credit';
    final timestamp = transaction['timestamp'] as Timestamp;
    final date = DateFormat('MMM dd, yyyy hh:mm a').format(timestamp.toDate());

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCredit ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isCredit ? Icons.add_circle : Icons.remove_circle,
              color: isCredit ? Colors.green.shade700 : Colors.red.shade700,
              size: 20,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCredit ? 'Added to wallet' : 'Withdrawal',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade900,
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}₹${transaction['amount'].toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isCredit ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRidesTab() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: _buildRidesHistory(),
    );
  }

  void _showAddMoneyDialog() {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.add_card,
                color: Colors.green.shade700,
                size: 32,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Add Money to Wallet',
              style: TextStyle(
                color: Colors.green.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  labelStyle: TextStyle(color: Colors.green.shade700),
                  prefixText: '₹',
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green.shade400),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: Colors.green.shade50,
                ),
              ),
              SizedBox(height: 12),
              // Compact Transaction Fee Info
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.green.shade700,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Transaction Fee: ',
                    style: TextStyle(
                      color: Colors.green.shade900,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '₹${WalletService.TRANSACTION_FEE}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                _walletService.addMoney(amount);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Add Money'),
          ),
        ],
        actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _showWithdrawDialog() {
    final amountController = TextEditingController();
    final maxWithdrawable = _walletBalance - WalletService.TRANSACTION_FEE;
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance,
                  color: Colors.blue.shade700,
                  size: 32,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Withdraw Money',
                style: TextStyle(
                  color: Colors.blue.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      final amount = double.tryParse(value) ?? 0;
                      if (amount <= 0) {
                        errorText = 'Please enter a valid amount';
                      } else if (amount + WalletService.TRANSACTION_FEE > _walletBalance) {
                        errorText = 'Insufficient balance. ';
                      } else {
                        errorText = null;
                      }
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    labelStyle: TextStyle(color: Colors.blue.shade700),
                    prefixText: '₹',
                    errorText: errorText,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade400),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.blue.shade50,
                  ),
                ),
                SizedBox(height: 12),
                // Compact Transaction Fee Info
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.blue.shade700,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Transaction Fee: ',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '₹${WalletService.TRANSACTION_FEE}',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Max withdrawable: ₹${maxWithdrawable.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              onPressed: errorText != null ? null : () async {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  try {
                    await _walletService.withdrawMoney(amount);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Withdrawal request submitted'),
                        backgroundColor: Colors.blue.shade600,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Withdraw'),
            ),
          ],
          actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  void _showPaymentSuccessDialog(double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/Tick.gif',
                height: 100,
                width: 100,
              ),
              SizedBox(height: 24),
              Text(
                'Payment Successful!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              SizedBox(height: 16),
              Text(
                '₹${amount.toStringAsFixed(2)} added to wallet',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'New Balance: ₹${_walletBalance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.green.shade600,
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _agentSubscription?.cancel();
    _paymentSuccessSubscription?.cancel();
    super.dispose();
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

  Widget _buildRidesHistory() {
    return Expanded(
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
    );
  }

  Widget _buildWalletCard() {
    return Container(
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
                      Icons.wallet,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Wallet Balance',
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
                '₹${_walletBalance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showAddMoneyDialog(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.green.shade700,
                        elevation: 0,
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
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Withdraw'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
