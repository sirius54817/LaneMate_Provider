import 'package:ecub_delivery/services/user_service.dart';
import 'package:ecub_delivery/services/auth_service.dart';
import 'package:ecub_delivery/pages/login.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ecub_delivery/pages/document_submission.dart';

enum VerificationStatus {
  loading,
  verified,
  unverified,
  pending,
  initial
}

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final UserService _userService = UserService();
  Future<Map<String, dynamic>?>? _userDataFuture;
  VerificationStatus _verificationStatus = VerificationStatus.initial;
  bool _isCheckingVerification = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _initialVerificationCheck();
  }

  void _refreshData() {
    setState(() {
      _userDataFuture = _userService.fetchUserData();
    });
    _initialVerificationCheck();
  }

  Future<void> _initialVerificationCheck() async {
    try {
      final verificationData = await _getVerificationStatus();
      
      if (verificationData == null) {
        setState(() => _verificationStatus = VerificationStatus.initial);
        return;
      }

      final submissionStatus = verificationData['submissionStatus'] as String?;
      final isLicenseValid = verificationData['isLicenseValid'] as bool? ?? false;
      final isPanValid = verificationData['isPanValid'] as bool? ?? false;
      final isOverallDataValid = verificationData['isOverallDataValid'] as bool? ?? false;
      final submittedAt = verificationData['submittedAt'];

      setState(() {
        if (isOverallDataValid && isLicenseValid && isPanValid) {
          _verificationStatus = VerificationStatus.verified;
        } else if (submissionStatus == 'pending' && submittedAt != null) {
          _verificationStatus = VerificationStatus.pending;
        } else {
          _verificationStatus = VerificationStatus.unverified;
        }
      });
    } catch (e) {
      print('Error in initial verification check: $e');
      setState(() => _verificationStatus = VerificationStatus.initial);
    }
  }

  Future<Map<String, dynamic>?> _getVerificationStatus() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('driver_verifications')
        .doc(userId)
        .get();

    return doc.data();
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.blue[700]),
              SizedBox(width: 10),
              Text(
                'Logout',
                style: TextStyle(
                  color: Colors.blue[900],
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                await AuthService().signout(context: context);
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => Login()),
                  (route) => false,
                );
              },
              child: Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditDialog(Map<String, dynamic> userData) async {
    final TextEditingController phoneController = TextEditingController(
      text: userData['phone'] ?? ''
    );
    final TextEditingController locationController = TextEditingController(
      text: userData['userLocation'] ?? ''
    );

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.edit, color: Colors.blue[700]),
              SizedBox(width: 10),
              Text(
                'Edit Profile',
                style: TextStyle(
                  color: Colors.blue[900],
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone, color: Colors.blue[700]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    prefixIcon: Icon(Icons.location_on, color: Colors.blue[700]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final userId = FirebaseAuth.instance.currentUser?.uid;
                  if (userId == null) return;

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .update({
                    'phone': phoneController.text.trim(),
                    'userLocation': locationController.text.trim(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  if (!mounted) return;
                  Navigator.of(context).pop();
                  _refreshData(); // Refresh the profile data
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Profile updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update profile: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(
                'Save',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVerificationSection(Map<String, dynamic> userData) {
    return StatefulBuilder(
      builder: (context, setState) {
        Color getStatusColor() {
          switch (_verificationStatus) {
            case VerificationStatus.loading:
              return Colors.grey;
            case VerificationStatus.verified:
              return const Color(0xFF2E7D32);
            case VerificationStatus.unverified:
              return Colors.red;
            case VerificationStatus.pending:
              return Colors.blue;
            case VerificationStatus.initial:
              return Colors.orange;
          }
        }

        String getStatusText() {
          switch (_verificationStatus) {
            case VerificationStatus.loading:
              return 'Checking verification status...';
            case VerificationStatus.verified:
              return 'Verified ✓';
            case VerificationStatus.unverified:
              return 'Not Verified';
            case VerificationStatus.pending:
              return 'Documents under review';
            case VerificationStatus.initial:
              return 'Submit your documents to start giving rides';
          }
        }

        IconData getStatusIcon() {
          switch (_verificationStatus) {
            case VerificationStatus.loading:
              return Icons.safety_check;
            case VerificationStatus.verified:
              return Icons.verified_user;
            case VerificationStatus.unverified:
              return Icons.gpp_bad;
            case VerificationStatus.pending:
              return Icons.pending;
            case VerificationStatus.initial:
              return Icons.upload_file;
          }
        }

        Future<void> checkVerificationStatus() async {
          if (_isCheckingVerification) return;

          setState(() {
            _isCheckingVerification = true;
            _verificationStatus = VerificationStatus.loading;
          });

          try {
            final verificationData = await _getVerificationStatus();
            
            if (verificationData == null) {
              setState(() => _verificationStatus = VerificationStatus.initial);
              return;
            }

            final submissionStatus = verificationData['submissionStatus'] as String?;
            final isLicenseValid = verificationData['isLicenseValid'] as bool? ?? false;
            final isPanValid = verificationData['isPanValid'] as bool? ?? false;
            final isOverallDataValid = verificationData['isOverallDataValid'] as bool? ?? false;
            final submittedAt = verificationData['submittedAt'];

            setState(() {
              if (isOverallDataValid && isLicenseValid && isPanValid) {
                _verificationStatus = VerificationStatus.verified;
              } else if (submissionStatus == 'pending' && submittedAt != null) {
                _verificationStatus = VerificationStatus.pending;
              } else {
                _verificationStatus = VerificationStatus.unverified;
              }
            });
          } catch (e) {
            print('Error checking verification status: $e');
            setState(() => _verificationStatus = VerificationStatus.initial);
          } finally {
            setState(() => _isCheckingVerification = false);
          }
        }

        final statusColor = getStatusColor();

        return InkWell(
          onTap: checkVerificationStatus,
          child: Container(
            margin: EdgeInsets.only(top: 20),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _verificationStatus == VerificationStatus.loading 
                  ? Colors.grey[100]
                  : _verificationStatus == VerificationStatus.verified
                      ? const Color(0xFFE8F5E9)
                      : statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: _verificationStatus == VerificationStatus.verified
                    ? const Color(0xFF81C784)
                    : statusColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _verificationStatus == VerificationStatus.loading
                        ? SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                            ),
                          )
                        : Icon(getStatusIcon(), color: statusColor, size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Identity Verification',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _verificationStatus == VerificationStatus.verified
                                  ? const Color(0xFF1B5E20)
                                  : statusColor,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            getStatusText(),
                            style: TextStyle(
                              fontSize: 14,
                              color: _verificationStatus == VerificationStatus.verified
                                  ? const Color(0xFF2E7D32)
                                  : statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_verificationStatus != VerificationStatus.verified && 
                    _verificationStatus != VerificationStatus.loading) ...[
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DocumentSubmissionPage(),
                        ),
                      );
                      if (result == true) {
                        checkVerificationStatus();
                      }
                    },
                    icon: Icon(Icons.upload_file, size: 20, color: Colors.white),
                    label: Text('Submit Documents'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
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
              'Profile',
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _userDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: Colors.blue[700])
            );
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red[400], size: 60),
                  SizedBox(height: 16),
                  Text(
                    "Error loading profile",
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Force a rebuild to retry
                      (context as Element).markNeedsBuild();
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_outlined, color: Colors.grey[400], size: 60),
                  SizedBox(height: 16),
                  Text(
                    "Profile data not found",
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await AuthService().signout(context: context);
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => Login()),
                        (route) => false,
                      );
                    },
                    child: Text('Return to Login'),
                  ),
                ],
              ),
            );
          }

          Map<String, dynamic> userData = snapshot.data!;
          String displayLocation = userData['userLocation'] ?? 'Not set';

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Profile Card
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.blue[200]!,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blue[100],
                          backgroundImage: AssetImage('assets/images/man.jpeg'),
                        ),
                        SizedBox(height: 15),
                        Text(
                          userData['name'] ?? 'Name not available',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[700],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'User since ${userData['createdAt'].toDate().year}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  // Add verification section before details card
                  _buildVerificationSection(userData),
                  SizedBox(height: 20),
                  // Details Card
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Personal Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _showEditDialog(userData),
                              icon: Icon(Icons.edit, color: Colors.blue[700]),
                              tooltip: 'Edit Details',
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        ProfileItem(
                          icon: Icons.phone,
                          label: "Phone",
                          value: userData['phone'] ?? 'Not available',
                        ),
                        Divider(color: Colors.blue[100]),
                        ProfileItem(
                          icon: Icons.mail,
                          label: "Email",
                          value: userData['email'] ?? 'Not available',
                          isEditable: false,
                        ),
                        Divider(color: Colors.blue[100]),
                        ListTile(
                          leading: Icon(Icons.location_on),
                          title: Text('Location'),
                          subtitle: Text(displayLocation),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => _showLogoutConfirmation(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[50],
                            foregroundColor: Colors.red[700],
                            elevation: 0,
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout, color: Colors.red[700]),
                              SizedBox(width: 8),
                              Text(
                                'Logout',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isEditable;

  ProfileItem({
    required this.icon,
    required this.label,
    required this.value,
    this.isEditable = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue[700], size: 20),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (!isEditable) ...[
                      SizedBox(width: 4),
                      Icon(
                        Icons.lock_outline,
                        size: 12,
                        color: Colors.grey[400],
                      ),
                    ],
                  ],
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue[900],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<Map<String, dynamic>?> _fetchUserData() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return null;

    return doc.data();
  } catch (e) {
    print('Error fetching user data: $e');
    return null;
  }
}
