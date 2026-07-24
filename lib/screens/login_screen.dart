import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';
import 'landing_screen.dart'; // Add import

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Use the specific Client ID for Web, otherwise null (default) for Android/iOS
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? '960573537207-r7k8i6sh833gupogpfc5cg3afm6julu0.apps.googleusercontent.com' : null,
  );
  bool _isLoading = false;

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Trigger Google Sign In Flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false); // User cancelled
        return;
      }

      // 2. Domain Restriction Check
      if (!googleUser.email.endsWith('@hyderabad.bits-pilani.ac.in') && googleUser.email != 'mulagaleti.sreerama@gmail.com' && googleUser.email != 'sais72@gmail.com') {
        await _googleSignIn.signOut();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Access Denied: Please use your BITS Pilani Hyderabad Email ID."),
          backgroundColor: Colors.red,
        ));
        setState(() => _isLoading = false);
        return;
      }

      // 3. Get Auth Credentials
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
         throw Exception("Missing Auth Tokens. Please try again.");
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign In to Firebase
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // 5. Check if Profile is Complete
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        
        bool isProfileComplete = false;
        if (userDoc.exists && userDoc.data() != null) {
           final data = userDoc.data() as Map<String, dynamic>;
           if (data.containsKey('studentId')) {
             isProfileComplete = true;
           }
        }



// ...

        if (isProfileComplete) {
          // Profile exists and has data -> Go to Landing Screen
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LandingScreen()));
        } else {
          // New User or Incomplete Profile -> Go to Setup
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProfileSetupScreen()));
        }
      }

    } catch (e) {
      print("Login Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Failed: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          // Background subtle ambient radial glow
          Positioned(
            top: -100,
            left: MediaQuery.of(context).size.width / 2 - 150,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo container with Vercel-style subtle border
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF09090B),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFF27272A)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.8),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/RentX_logo.png',
                      height: 100,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.bolt,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // App Title
                  const Text(
                    "RentX",
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFAFAFA),
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // New Slogan & Subtitle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF27272A)),
                    ),
                    child: const Text(
                      "Rent Anything • Buy Anything • Ride Anywhere",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFA1A1AA),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    "BITS Pilani Hyderabad Campus Marketplace",
                    style: TextStyle(color: Color(0xFF71717A), fontSize: 12),
                  ),

                  const SizedBox(height: 48),

                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : ElevatedButton.icon(
                          onPressed: _handleSignIn,
                          icon: Image.network(
                            'https://cdn-icons-png.flaticon.com/512/300/300221.png',
                            height: 22,
                            errorBuilder: (_, __, ___) => const Icon(Icons.login, color: Colors.black, size: 20),
                          ),
                          label: const Text(
                            "Continue with BITS Google ID",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFAFAFA),
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}