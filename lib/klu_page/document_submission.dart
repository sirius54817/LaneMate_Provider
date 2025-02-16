import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

class DocumentSubmissionPage extends StatefulWidget {
  @override
  _DocumentSubmissionklu_pagetate createState() => _DocumentSubmissionklu_pagetate();
}

class _DocumentSubmissionklu_pagetate extends State<DocumentSubmissionPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _panController = TextEditingController();
  
  File? _licenseImage;
  File? _panImage;
  bool _isLoading = false;

  @override
  void dispose() {
    _licenseController.dispose();
    _panController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isLicense) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          if (isLicense) {
            _licenseImage = File(image.path);
          } else {
            _panImage = File(image.path);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<String?> _uploadImage(File image, String path) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(path);
      final uploadTask = ref.putFile(image);
      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _submitDocuments() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw 'User not found';

      if (_licenseImage == null || _panImage == null) {
        throw 'Please upload both documents';
      }

      // Upload license image
      final licenseRef = FirebaseStorage.instance
          .ref()
          .child('driver_documents/$userId/license.jpg');
      await licenseRef.putFile(_licenseImage!);
      final licenseUrl = await licenseRef.getDownloadURL();

      // Upload PAN image
      final panRef = FirebaseStorage.instance
          .ref()
          .child('driver_documents/$userId/pan.jpg');
      await panRef.putFile(_panImage!);
      final panUrl = await panRef.getDownloadURL();

      // Update Firestore document
      await FirebaseFirestore.instance
          .collection('driver_verifications')
          .doc(userId)
          .update({
        'drivingLicenseNumber': _licenseController.text.trim(),
        'drivingLicensePicUrl': licenseUrl,
        'panNumber': _panController.text.trim(),
        'panPicUrl': panUrl,
        'submissionStatus': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isLicenseValid': false,
        'isPanValid': false,
        'isOverallDataValid': false,
      });

      if (!mounted) return;
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Documents submitted successfully'),
          backgroundColor: const Color(0xFF8CB73D),
        ),
      );
      
      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      if (!mounted) return;
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is String ? e : 'Error submitting documents. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = const Color(0xFF8CB73D);
    final darkAccentColor = const Color(0xFF8CB73D);  // Using same accent color

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'LaneMate',
              style: TextStyle(
                color: darkAccentColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              ' • ',
              style: TextStyle(
                color: accentColor,
                fontSize: 22,
              ),
            ),
            Text(
              'Document Submission',
              style: TextStyle(
                color: darkAccentColor,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: darkAccentColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: darkAccentColor))
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: accentColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, 
                                color: darkAccentColor, size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Please submit clear photos of your documents for verification',
                                style: TextStyle(
                                  color: darkAccentColor,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      _buildDocumentSection(
                        title: 'Driving License',
                        controller: _licenseController,
                        isLicense: true,
                        accentColor: accentColor,
                        darkAccentColor: darkAccentColor,
                      ),
                      SizedBox(height: 24),
                      _buildDocumentSection(
                        title: 'PAN Card',
                        controller: _panController,
                        isLicense: false,
                        accentColor: accentColor,
                        darkAccentColor: darkAccentColor,
                      ),
                      SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitDocuments,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkAccentColor,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Submit Documents',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildDocumentSection({
    required String title,
    required TextEditingController controller,
    required bool isLicense,
    required Color accentColor,
    required Color darkAccentColor,
  }) {
    final File? currentImage = isLicense ? _licenseImage : _panImage;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: darkAccentColor,
          ),
        ),
        SizedBox(height: 12),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: '$title Number',
            prefixIcon: Icon(
              isLicense ? Icons.drive_eta : Icons.credit_card,
              color: darkAccentColor,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accentColor),
            ),
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Please enter $title number';
            }
            return null;
          },
        ),
        SizedBox(height: 12),
        InkWell(
          onTap: () => _pickImage(isLicense),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accentColor.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                if (currentImage != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      currentImage,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  SizedBox(height: 12),
                ] else
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 48,
                    color: accentColor,
                  ),
                Text(
                  currentImage != null ? 'Tap to change photo' : 'Tap to upload photo',
                  style: TextStyle(
                    color: darkAccentColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
} 