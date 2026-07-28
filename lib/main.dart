import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:campuspks/screens/login_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:campuspks/screens/landing_screen.dart';

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
  runApp(const MyApp());
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
      home: const _RootRouter(),
    );
  }
}

class _RootRouter extends StatefulWidget {
  const _RootRouter();

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  bool _updateChecked = false;
  bool _forceUpdate = false;
  String _storeUrl = 'https://play.google.com/store/apps/details?id=com.sreerama.campuspks';

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final int currentBuild = int.tryParse(info.buildNumber) ?? 0;

      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final int minVersion = (data['minVersionCode'] as num?)?.toInt() ?? 0;
        final String? storeLink = data['storeUrl'] as String?;
        if (storeLink != null && storeLink.isNotEmpty) {
          _storeUrl = storeLink;
        }
        if (currentBuild < minVersion) {
          if (mounted) setState(() => _forceUpdate = true);
          return;
        }
      }
    } catch (e) {
      debugPrint("Update check failed (non-fatal): $e");
    }
    if (mounted) setState(() => _updateChecked = true);
  }

  @override
  Widget build(BuildContext context) {
    // Force-update wall
    if (_forceUpdate) {
      return Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/rentx_logo_new.png', height: 117,
                    errorBuilder: (e, s, t) => const Icon(Icons.bolt, size: 78, color: Colors.white)),
                  const SizedBox(height: 32),
                  const Text(
                    "Update Required",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "A newer version of RentX is required to continue. Please update from the Play Store.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 36),
                  ElevatedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(_storeUrl), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.system_update_outlined, color: Colors.black),
                    label: const Text(
                      "Update on Play Store",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFAFAFA),
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Loading / auth check
    if (!_updateChecked) {
      return Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/rentx_logo_new.png', height: 117,
                errorBuilder: (e, s, t) => Image.asset('assets/images/RentX_logo.png', height: 117)),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ],
          ),
        ),
      );
    }

    // Normal auth stream
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFF000000),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/rentx_logo_new.png', height: 117,
                    errorBuilder: (e, s, t) => Image.asset('assets/images/RentX_logo.png', height: 117)),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ],
              ),
            ),
          );
        }
        if (snapshot.hasData) return LandingScreen();
        return LoginScreen();
      },
    );
  }
}