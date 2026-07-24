import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:campuspks/screens/login_screen.dart';
import 'package:campuspks/screens/home_screen.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:campuspks/screens/landing_screen.dart'; // Add import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyA7WUUXsHhcVeAZEtlluFjYMfHW8nu5mOM",
          authDomain: "campus-spokes.firebaseapp.com",
          projectId: "campus-spokes",
          storageBucket: "campus-spokes.firebasestorage.app",
          messagingSenderId: "960573537207",
          appId: "1:960573537207:web:26b88cc7514544f9824632",
          measurementId: "G-BXQVGLTJ5T",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
    debugPrint("Firebase initialized successfully");
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RentX — Campus Mobility & Marketplace',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        primaryColor: Colors.white,
        cardColor: const Color(0xFF09090B),
        canvasColor: const Color(0xFF09090B),
        dividerColor: const Color(0xFF27272A),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: const Color(0xFFFAFAFA),
          displayColor: const Color(0xFFFAFAFA),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: const Color(0xFF000000),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/RentX_logo.png', height: 100),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ],
                ),
              ),
            );
          }


// ...

          if (snapshot.hasData) {
            return LandingScreen();
          }
          return LoginScreen();
        },
      ),
    );
  }
}