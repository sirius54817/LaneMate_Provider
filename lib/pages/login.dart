import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:ecub_delivery/pages/signup.dart';
import 'package:ecub_delivery/services/auth_service.dart';
import 'package:ecub_delivery/pages/navigation.dart' as regular;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ecub_delivery/klu_page/navigation.dart' as klu;

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoggingIn = false;

  final List<String> carouselImages = [
    'assets/carousel1.png',
    'assets/carousel2.png',
    'assets/carousel3.png',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 80),
                Text(
                  'LaneMates',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                Text(
                  'Welcome Back!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width: 350,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _loginTextField(
                            controller: _emailController,
                            hintText: 'Email',
                            shadowText: 'Enter your email',
                          ),
                          const SizedBox(height: 15),
                          _loginTextField(
                            controller: _passwordController,
                            hintText: 'Password',
                            shadowText: 'Enter your password',
                            obscureText: !_isPasswordVisible,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible 
                                  ? Icons.visibility 
                                  : Icons.visibility_off,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 25),
                          _signInButton(context),
                          const SizedBox(height: 15),
                          _signUpLink(context),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _bottomCarousel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomCarousel() {
    return CarouselSlider(
      options: CarouselOptions(
        height: 220, // Increased from 120 to 220
        autoPlay: true,
        enlargeCenterPage: true,
        aspectRatio: 16/9,
        autoPlayCurve: Curves.fastOutSlowIn,
        enableInfiniteScroll: true,
        autoPlayAnimationDuration: const Duration(milliseconds: 800),
      ),
      items: carouselImages.map((imagePath) {
        return Builder(
          builder: (BuildContext context) {
            return Container(
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.symmetric(horizontal: 5.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                image: DecorationImage(
                  image: AssetImage(imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  // Rest of the code remains unchanged
  Widget _loginTextField({
    required TextEditingController controller,
    required String hintText,
    required String shadowText,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: hintText,
        hintText: shadowText,
        hintStyle: TextStyle(
          color: Colors.black26,
          fontStyle: FontStyle.italic,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _signInButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.lightGreen.shade400,
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      onPressed: _isLoggingIn ? null : _performLogin,
      child: _isLoggingIn
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Text(
              "Sign In",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
    );
  }

  Widget _signUpLink(BuildContext context) {
    return Center(
      child: RichText(
        text: TextSpan(
          children: [
            const TextSpan(
              text: "New User? ",
              style: TextStyle(color: Colors.black54),
            ),
            TextSpan(
              text: "Create Account",
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Signup()),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _performLogin() async {
    setState(() => _isLoggingIn = true);

    try {
      // Check if user exists in users collection
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailController.text)
          .get();

      if (userSnapshot.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No account found with this email'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoggingIn = false);
        return;
      }

      // Attempt to sign in and wait for the result
      final UserCredential? userCredential = await AuthService().signin(
        email: _emailController.text,
        password: _passwordController.text,
        context: context,
      );

      // If sign in failed or user is null, show incorrect password message
      if (userCredential == null || userCredential.user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect password'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating, // Makes it float above content
            margin: EdgeInsets.all(10), // Adds margin around the snackbar
          ),
        );
        setState(() => _isLoggingIn = false);
        return;
      }

      // Only proceed with navigation if authentication was successful
      if (!mounted) return;

      // Check email domain and redirect accordingly
      final email = _emailController.text.toLowerCase();
      if (email.endsWith('@klu.ac.in')) {
        // Redirect KLU users to KLU navigation
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const klu.MainNavigation(),
          ),
        );
      } else {
        // Redirect other users to regular navigation
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const regular.MainNavigation(),
          ),
        );
      }

      // After successful login, check if user has completed driver verification
      final userId = userCredential.user?.uid;
      if (userId != null) {
        final driverVerification = await FirebaseFirestore.instance
            .collection('driver_verifications')
            .doc(userId)
            .get();

        if (driverVerification.exists) {
          final isVerified = driverVerification.data()?['isOverallDataValid'] ?? false;
          if (!isVerified) {
            final hasSubmitted = driverVerification.data()?['submittedAt'] != null;
            if (hasSubmitted && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Your driver verification is pending approval'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(10),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }
}