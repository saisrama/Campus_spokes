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
          // PROFILE HEADER CARD (COMPACT HORIZONTAL)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF09090B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF27272A), width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundImage: NetworkImage(user?.photoURL ?? "https://via.placeholder.com/150"),
                    backgroundColor: const Color(0xFF18181B),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? "Student",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFAFAFA)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? "",
                        style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // PLATFORM NOTICE CARD
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF09090B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF94A3B8).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.gavel_rounded, color: Color(0xFF94A3B8), size: 16),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Platform Notice",
                      style: TextStyle(color: Color(0xFFFAFAFA), fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  "RentX acts solely as a peer-to-peer intermediary platform connecting students on campus. "
                  "All transactions, rentals, and purchases are conducted directly between the parties involved.",
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 8),
                const Text(
                  "RentX bears no liability for disputes, damages, losses, or misrepresentations arising from any listing or transaction. "
                  "Users are advised to verify item condition before accepting and to resolve any issues directly with the owner/seller.",
                  style: TextStyle(color: Color(0xFF71717A), fontSize: 11, height: 1.6),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _showTermsSheet(context),
                  child: const Text(
                    "Read full Terms & Conditions →",
                    style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

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

  void _showTermsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF09090B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 20),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text(
              "Terms & Conditions",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
            ),
            const SizedBox(height: 4),
            const Text(
              "Effective for all RentX platform users",
              style: TextStyle(color: Color(0xFF71717A), fontSize: 12),
            ),
            const SizedBox(height: 24),
            _termsSection(
              "1. Platform Role",
              "RentX is a peer-to-peer campus marketplace that connects students who wish to rent, lend, or sell items. "
              "RentX serves exclusively as a facilitating intermediary and is not a party to any transaction between users.",
            ),
            _termsSection(
              "2. No Liability",
              "RentX shall not be held responsible or liable for any disputes, damages, theft, loss, injury, misrepresentation, "
              "or conflicts that arise between users in connection with any listing, rental, sale, or in-person exchange. "
              "All interactions are at the users' own risk.",
            ),
            _termsSection(
              "3. Direct Resolution",
              "All disputes must be resolved directly between the parties involved (owner/seller and renter/buyer). "
              "RentX does not guarantee or mediate any resolution, refund, or compensation. "
              "We strongly encourage users to verify item condition in person before completing any handover.",
            ),
            _termsSection(
              "4. User Responsibility",
              "By using RentX, you agree that you are solely responsible for your listings, the accuracy of item descriptions, "
              "and the condition of items at the time of handover. Owners must ensure items are safe and functional before listing them.",
            ),
            _termsSection(
              "5. Payments",
              "RentX does not process or hold any payments. All financial transactions are arranged directly between users. "
              "RentX is not responsible for failed payments, overcharges, or payment disputes.",
            ),
            _termsSection(
              "6. Privacy",
              "Phone numbers and contact details shared on the platform are used solely for facilitating communication "
              "between parties for a transaction. Do not share sensitive personal information beyond what is necessary.",
            ),
            _termsSection(
              "7. Conduct",
              "Users agree to interact respectfully and honestly. Fraudulent listings, misuse of contact information, "
              "or abusive behaviour will result in removal from the platform.",
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Text(
                "By using RentX, you acknowledge that you have read, understood, and agreed to these terms. "
                "If you have a grievance, please reach out via the \"File Grievance\" option on your profile.",
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.6),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _termsSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              height: 1.65,
            ),
          ),
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