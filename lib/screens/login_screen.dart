import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';

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
        
        if (userDoc.exists && (userDoc.data() as Map<String, dynamic>).containsKey('studentId')) {
          // Profile exists and has data -> Go Home
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', height: 120),
            SizedBox(height: 20),
            Text("CAMPUS SPOKES", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("Ride. Share. Explore.", style: TextStyle(color: Colors.grey)),
            SizedBox(height: 50),
            
            _isLoading 
              ? CircularProgressIndicator(color: Colors.white)
              : ElevatedButton.icon(
                  onPressed: _handleSignIn,
                  icon: Image.network('https://cdn-icons-png.flaticon.com/512/300/300221.png', height: 24), // Reliable Google Icon
                  label: Text("Login with Google", style: TextStyle(color: Colors.black, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}