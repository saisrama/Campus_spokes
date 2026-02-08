import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:campuspks/screens/login_screen.dart';
import 'package:campuspks/screens/home_screen.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb

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
      title: 'College Cycle Share',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Color(0xFF121212),
        primaryColor: Colors.white,
        cardColor: Color(0xFF1E1E1E),
        // Applies Oswald font globally
        textTheme: GoogleFonts.oswaldTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/logo.png', height: 100),
                    SizedBox(height: 20),
                    CircularProgressIndicator(color: Colors.white),
                  ],
                ),
              ),
            );
          }
          if (snapshot.hasData) {
            return HomeScreen();
          }
          return LoginScreen();
        },
      ),
    );
  }
}