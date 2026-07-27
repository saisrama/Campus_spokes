import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'profile_setup_screen.dart';
import 'landing_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? '960573537207-r7k8i6sh833gupogpfc5cg3afm6julu0.apps.googleusercontent.com' : null,
  );
  bool _isLoading = false;

  // Ticker for the feature classifier
  late final PageController _featurePageController;
  late final List<_FeatureItem> _features;
  int _currentFeaturePage = 0;

  @override
  void initState() {
    super.initState();
    _features = const [
      _FeatureItem(icon: Icons.pedal_bike_outlined, label: "Rent a Cycle", sub: "Quick campus rides from ₹10/hr"),
      _FeatureItem(icon: Icons.inventory_2_outlined, label: "Rent Anything", sub: "Electronics, tools, sports gear"),
      _FeatureItem(icon: Icons.shopping_bag_outlined, label: "Buy & Sell", sub: "Peer-to-peer campus marketplace"),
      _FeatureItem(icon: Icons.explore_outlined, label: "Explore Campus", sub: "Eateries & destinations nearby"),
      _FeatureItem(icon: Icons.campaign_outlined, label: "Post Requests", sub: "Can't find it? Post a request"),
    ];
    _featurePageController = PageController(viewportFraction: 0.75);
    // Auto-scroll every 3 seconds
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return false;
      final next = (_currentFeaturePage + 1) % _features.length;
      if (_featurePageController.hasClients) {
        _featurePageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
      if (mounted) setState(() => _currentFeaturePage = next);
      return mounted;
    });
  }

  @override
  void dispose() {
    _featurePageController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      if (!googleUser.email.endsWith('@hyderabad.bits-pilani.ac.in') &&
          googleUser.email != 'mulagaleti.sreerama@gmail.com' &&
          googleUser.email != 'sais72@gmail.com') {
        await _googleSignIn.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Access Denied: Please use your BITS Pilani Hyderabad Email ID."),
          backgroundColor: Colors.red,
        ));
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw Exception("Missing Auth Tokens. Please try again.");
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        bool isProfileComplete = false;
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data() as Map<String, dynamic>;
          if (data.containsKey('studentId')) {
            isProfileComplete = true;
          }
        }

        if (isProfileComplete) {
          if (!mounted) return;
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LandingScreen()));
        } else {
          if (!mounted) return;
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProfileSetupScreen()));
        }
      }
    } catch (e) {
      debugPrint("Login Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Login Failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          // Ambient glow
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
                    Colors.white.withValues(alpha: 0.06),
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
                  // ── NEW LOGO (rentx_logo (1).png) ──
                  Container(
                    padding: const EdgeInsets.all(20),
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
                      'assets/images/rentx_logo_new.png',
                      height: 110,
                      fit: BoxFit.contain,
                      errorBuilder: (e, s, t) => const Icon(Icons.bolt, size: 80, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── SLOGAN PILL ──
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
                  const SizedBox(height: 8),
                  const Text(
                    "BITS Pilani Hyderabad Campus Marketplace",
                    style: TextStyle(color: Color(0xFF52525B), fontSize: 11),
                  ),

                  const SizedBox(height: 32),

                  // ── RUNNING FEATURES CLASSIFIER ──
                  SizedBox(
                    height: 90,
                    child: PageView.builder(
                      controller: _featurePageController,
                      itemCount: _features.length,
                      onPageChanged: (i) => setState(() => _currentFeaturePage = i),
                      itemBuilder: (context, index) {
                        final f = _features[index];
                        final bool active = index == _currentFeaturePage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: active ? const Color(0xFF09090B) : const Color(0xFF09090B).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: active ? const Color(0xFF52525B) : const Color(0xFF27272A),
                              width: active ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: active ? 0.1 : 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(f.icon, color: active ? Colors.white : const Color(0xFF71717A), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(f.label, style: TextStyle(color: active ? Colors.white : const Color(0xFF71717A), fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 3),
                                    Text(f.sub, style: const TextStyle(color: Color(0xFF71717A), fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Page dots
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_features.length, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _currentFeaturePage ? 16 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: i == _currentFeaturePage ? Colors.white : const Color(0xFF3F3F46),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),

                  const SizedBox(height: 40),

                  // ── SIGN IN BUTTON ──
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : ElevatedButton.icon(
                          onPressed: _handleSignIn,
                          icon: Image.network(
                            'https://cdn-icons-png.flaticon.com/512/300/300221.png',
                            height: 22,
                            errorBuilder: (e, s, t) => const Icon(Icons.login, color: Colors.black, size: 20),
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

class _FeatureItem {
  final IconData icon;
  final String label;
  final String sub;
  const _FeatureItem({required this.icon, required this.label, required this.sub});
}