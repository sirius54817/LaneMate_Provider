import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>?> fetchUserData() async {
    try {
      String uid = _auth.currentUser!.uid;

      DocumentSnapshot userDoc =
          await _firestore.collection('delivery_agent').doc(uid).get();

      if (userDoc.exists) {
        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;

        if (data != null) {
          data['id'] = uid; // Add UID to data if you want to display it
        }

        return data;
      } else {
        print("User data not found.");
        return null;
      }
    } catch (e) {
      print("Error fetching user data: $e");
      return null;
    }
  }
}
