import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login_screen.dart';
import 'my_listings_screen.dart';
import 'ride_history_screen.dart';
import 'payment_history_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'profile_setup_screen.dart';
import 'received_bookings_screen.dart';

class ProfileScreen extends StatelessWidget {
  final User? user = FirebaseAuth.instance.currentUser;

  ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        title: const Text(
          "Profile",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              await GoogleSignIn().signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => LoginScreen()), (r) => false);
              }
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // PROFILE HEADER CARD
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF09090B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF27272A), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundImage: NetworkImage(user?.photoURL ?? "https://via.placeholder.com/150"),
                    backgroundColor: const Color(0xFF18181B),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  user?.displayName ?? "Student",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFAFAFA)),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? "",
                  style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: const Text(
                    "Rent Anything • Buy Anything • Ride Anywhere",
                    style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // MENU GROUP
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF09090B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Column(
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.edit,
                  color: const Color(0xFFA855F7),
                  title: "Edit Profile",
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileSetupScreen(isEditing: true))),
                ),
                const Divider(color: Color(0xFF18181B), height: 1),
                _buildMenuItem(
                  context,
                  icon: Icons.list_alt,
                  color: const Color(0xFF38BDF8),
                  title: "My Listings",
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MyListingsScreen())),
                ),
                const Divider(color: Color(0xFF18181B), height: 1),
                _buildMenuItem(
                  context,
                  icon: Icons.history,
                  color: const Color(0xFF818CF8),
                  title: "Your Rentals",
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RideHistoryScreen())),
                ),
                const Divider(color: Color(0xFF18181B), height: 1),
                _buildMenuItem(
                  context,
                  icon: Icons.bookmark_added,
                  color: const Color(0xFFFB923C),
                  title: "Received Bookings",
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReceivedBookingsScreen())),
                ),
                const Divider(color: Color(0xFF18181B), height: 1),
                _buildMenuItem(
                  context,
                  icon: Icons.payment,
                  color: const Color(0xFF34D399),
                  title: "Payment History",
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentHistoryScreen())),
                ),
                const Divider(color: Color(0xFF18181B), height: 1),
                _buildMenuItem(
                  context,
                  icon: Icons.support_agent,
                  color: const Color(0xFFFBBF24),
                  title: "File Grievance (WhatsApp)",
                  onTap: () async {
                    final Uri whatsappUrl = Uri.parse("https://wa.me/917022914482");
                    if (await canLaunchUrl(whatsappUrl)) {
                      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open WhatsApp")));
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // LOG OUT BUTTON
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF09090B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text("Log Out", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                await GoogleSignIn().signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => LoginScreen()), (r) => false);
                }
              },
            ),
          ),

          const SizedBox(height: 28),

          // CREDITS & ACKNOWLEDGMENTS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const Text(
                  "RentX • Made with ❤️ by Sai Sreerama M",
                  style: TextStyle(color: Color(0xFFFAFAFA), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Special thanks to:",
                  style: TextStyle(color: Color(0xFF71717A), fontSize: 10),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                const Text(
                  "Athithan V, Bhanuteja Abburi, Pariksheth Malathkar, Praneel S Gandhe, Madhav Praveen, Ram K Musti, Saket M, Sameer Singh, Srijen Raja and Yash Raj",
                  style: TextStyle(color: Color(0xFF71717A), fontSize: 9),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF71717A)),
    );
  }
}