import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class WalletService {
  static const double TRANSACTION_FEE = 1.5;
  final _razorpay = Razorpay();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _paymentSuccessController = StreamController<Map<String, dynamic>>.broadcast();
  final _paymentErrorController = StreamController<String>.broadcast();

  Stream<Map<String, dynamic>> get onPaymentSuccess => _paymentSuccessController.stream;
  Stream<String> get onPaymentError => _paymentErrorController.stream;

  WalletService() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final amount = _lastRequestedAmount ?? 0.0;
      final timestamp = Timestamp.now();
      
      await _firestore.collection('wallets').doc(userId).set({
        'balance': FieldValue.increment(amount),
        'transactions': FieldValue.arrayUnion([{
          'type': 'credit',
          'amount': amount,
          'fee': TRANSACTION_FEE,
          'timestamp': timestamp,
          'payment_id': response.paymentId,
          'orderId': response.orderId,
          'status': 'success'
        }])
      }, SetOptions(merge: true));

      _paymentSuccessController.add({
        'amount': amount,
        'paymentId': response.paymentId
      });
    } catch (e) {
      print('Error updating wallet: $e');
      _paymentErrorController.add(e.toString());
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('Payment error: ${response.message}');
  }

  double? _lastRequestedAmount;

  Future<void> addMoney(double amount) async {
    final totalAmount = amount + TRANSACTION_FEE;
    _lastRequestedAmount = amount;
    
    final options = {
      'key': 'rzp_test_CVbypqu6YtbzvT',
      'amount': (totalAmount * 100).toInt(), // Convert to paise
      'name': 'LaneMates Wallet',
      'description': 'Wallet Recharge',
      'prefill': {
        'contact': _auth.currentUser?.phoneNumber,
        'email': _auth.currentUser?.email,
      },
      'currency': 'INR',
      'theme': {
        'color': '#4CAF50',
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      _lastRequestedAmount = null;
      throw 'Payment failed: $e';
    }
  }

  Future<void> withdrawMoney(double amount) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw 'User not authenticated';

    final totalDeduction = amount + TRANSACTION_FEE;
    final timestamp = Timestamp.now();
    
    final walletRef = _firestore.collection('wallets').doc(userId);
    
    try {
      await _firestore.runTransaction((transaction) async {
        final wallet = await transaction.get(walletRef);
        final currentBalance = wallet.data()?['balance'] ?? 0.0;
        
        if (currentBalance < totalDeduction) {
          throw 'Insufficient balance';
        }

        transaction.update(walletRef, {
          'balance': currentBalance - totalDeduction,
          'pending_withdrawals': FieldValue.arrayUnion([{
            'amount': amount,
            'fee': TRANSACTION_FEE,
            'status': 'pending',
            'timestamp': timestamp,
          }])
        });
      });
    } catch (e) {
      throw 'Withdrawal failed: $e';
    }
  }

  Stream<DocumentSnapshot> getWalletStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw 'User not authenticated';
    
    return _firestore.collection('wallets').doc(userId).snapshots();
  }

  @override
  void dispose() {
    _razorpay.clear();
    _paymentSuccessController.close();
    _paymentErrorController.close();
  }
} 