import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>?> fetchUserData() async {
    try {
      String uid = _auth.currentUser!.uid;

      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists) {
        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;

        if (data != null) {
          DocumentSnapshot verificationDoc = 
              await _firestore.collection('driver_verifications').doc(uid).get();
          
          if (verificationDoc.exists) {
            Map<String, dynamic> verificationData = 
                verificationDoc.data() as Map<String, dynamic>;
            data['isVerified'] = verificationData['isOverallDataValid'] ?? false;
            data['verificationStatus'] = verificationData['submissionStatus'];
          } else {
            data['isVerified'] = false;
            data['verificationStatus'] = 'not_submitted';
          }

          data['id'] = uid;
        }

        return data;
      } else {
        print("User data not found in 'users' collection");
        return null;
      }
    } catch (e) {
      print("Error fetching user data: $e");
      return null;
    }
  }
}
