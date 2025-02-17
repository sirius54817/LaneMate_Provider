import 'package:ecub_delivery/pages/home.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ecub_delivery/pages/navigation.dart';
import '../pages/login.dart';

class AuthService {
  Future<void> signup({
    required String name,
    required String email,
    required String phone,
    required String password,
    required BuildContext context,
  }) async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      User? user = userCredential.user;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'id': user.uid,
          'name': name,
          'email': email,
          'phone': phone,
          'isRideProvider': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Create initial driver verification document
        await FirebaseFirestore.instance
            .collection('driver_verifications')
            .doc(user.uid)
            .set({
          'userId': user.uid,
          'submissionStatus': 'pending',
          'isLicenseValid': false,
          'isPanValid': false,
          'isOverallDataValid': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Sign out the user after successful registration
        await FirebaseAuth.instance.signOut();

        if (!context.mounted) return;
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Please login.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to login page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (BuildContext context) => const Login()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = '';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists with that email.';
      } else {
        message = e.message ?? 'An error occurred during signup.';
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> submitDriverVerification({
    required String userId,
    required String fullName,
    required String drivingLicenseNumber,
    required String drivingLicensePicUrl,
    required String panNumber,
    required String panPicUrl,
    required String carPlateNumber,
    required String carPlatePicUrl,
    required String userProfilePicUrl,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('driver_verifications')
          .doc(userId)
          .update({
        'fullName': fullName,
        'drivingLicenseNumber': drivingLicenseNumber,
        'drivingLicensePicUrl': drivingLicensePicUrl,
        'panNumber': panNumber,
        'panPicUrl': panPicUrl,
        'carPlateNumber': carPlateNumber,
        'carPlatePicUrl': carPlatePicUrl,
        'userProfilePicUrl': userProfilePicUrl,
        'submissionStatus': 'submitted',
        'submittedAt': FieldValue.serverTimestamp(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to submit driver verification: $e';
    }
  }

  Future<UserCredential?> signin({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided for that user.';
      } else {
        message = e.message ?? 'An error occurred';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  Future<void> signout({required BuildContext context}) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    await Future.delayed(const Duration(seconds: 1));
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (BuildContext context) => Login()),
    );
  }
}
