import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:ecub_delivery/pages/signup.dart';
import 'package:ecub_delivery/services/auth_service.dart';
import 'package:ecub_delivery/pages/navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';


class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  final List<String> carouselImages = [
    'assets/carousel1.png',
    'assets/carousel2.png',
    'assets/carousel3.png',
    'assets/carousel4.png',
  ];

  // Add new field for captions
  final List<String> carouselCaptions = [
    "Hop in, Hassle out - Simple Pickup Points",
    "Always There When You Need",
    "Smooth Rides, Smoother Payments",
    "Perfect Pickup, Perfect Journey"
  ];

  int _currentCarouselIndex = 0;

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
                  style: GoogleFonts.montserrat(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Share the Journey, Share the Joy',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    // color: Colors.blue.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                // Text(
                //   'Welcome Back!',
                //   style: TextStyle(
                //     fontSize: 24,
                //     fontWeight: FontWeight.w600,
                //     color: Colors.black87,
                //   ),
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
    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 220,
            autoPlay: true,
            enlargeCenterPage: true,
            viewportFraction: 0.9,
            aspectRatio: 16/9,  // Fixed aspect ratio
            autoPlayCurve: Curves.fastOutSlowIn,
            enableInfiniteScroll: true,
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            onPageChanged: (index, reason) {
              setState(() {
                _currentCarouselIndex = index;
              });
            }
          ),
          items: List.generate(carouselImages.length, (index) {
            return Builder(
              builder: (BuildContext context) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      // BoxShadow(
                      //   color: Colors.black.withOpacity(0.2),
                      //   spreadRadius: 1,
                      //   blurRadius: 5,
                      // )
                    ],
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          clipBehavior: Clip.hardEdge,
                          child: AspectRatio(
                            aspectRatio: 16/9,
                            child: Image.asset(
                              carouselImages[index],
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(15),  // Changed this line
                        ),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 5,
                        ),  // Added margin
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
                          horizontal: 15,
                        ),
                        child: Text(
                          carouselCaptions[index],
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }
//
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
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.lightGreen.shade200,
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.lightGreen.shade200,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.lightGreen.shade400,
            width: 2,
          ),
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
      onPressed: _performLogin,
      child: const Text(
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
    try {
      final agentSnapshot = await FirebaseFirestore.instance
          .collection('delivery_agent')
          .where('email', isEqualTo: _emailController.text)
          .get();

      if (agentSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied: Not a registered delivery agent'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await AuthService().signin(
        email: _emailController.text,
        password: _passwordController.text,
        context: context,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainNavigation()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}