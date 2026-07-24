import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'item_home_screen.dart';
import 'buy_home_screen.dart';
import 'explore_screen.dart';
import 'add_cycle_screen.dart';
import 'add_item_screen.dart';
import 'add_sale_item_screen.dart';
import 'profile_screen.dart';

class LandingScreen extends StatelessWidget {
  final User? user = FirebaseAuth.instance.currentUser;

  LandingScreen({super.key});

  void _showListOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF09090B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
          decoration: BoxDecoration(
            color: const Color(0xFF09090B),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: const Color(0xFF27272A)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                "Create a Listing",
                style: TextStyle(
                  color: Color(0xFFFAFAFA),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Share your cycle or items with fellow BITSians",
                style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                tileColor: const Color(0xFF18181B),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.pedal_bike, color: Color(0xFF38BDF8)),
                ),
                title: const Text("List My Cycle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Put your cycle up for rent", style: TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddCycleScreen()));
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                tileColor: const Color(0xFF18181B),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF818CF8)),
                ),
                title: const Text("List an Item for Rent", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Electronics, sports, tools, lab gear & more", style: TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddItemScreen()));
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                tileColor: const Color(0xFF18181B),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.sell_outlined, color: Color(0xFFFB923C)),
                ),
                title: const Text("Sell an Item", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("List items for outright campus sale", style: TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddSaleItemScreen()));
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showListOptions(context),
        label: const Text(
          "List Item / Cycle",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.2),
        ),
        icon: const Icon(Icons.add, size: 20),
        backgroundColor: const Color(0xFFFAFAFA),
        foregroundColor: Colors.black,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TOP HEADER BAR
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF09090B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF27272A)),
                        ),
                        child: Image.asset(
                          'assets/images/RentX_logo.png',
                          height: 32,
                          width: 32,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.bolt, color: Colors.white, size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "RentX",
                            style: GoogleFonts.plusJakartaSans(
                              textStyle: const TextStyle(
                                color: Color(0xFFFAFAFA),
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                              ),
                            ),
                          ),
                          const Text(
                            "CAMPUS MARKETPLACE",
                            style: TextStyle(
                              color: Color(0xFF71717A),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Profile Avatar
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen())),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF27272A), width: 2),
                      ),
                      child: CircleAvatar(
                        backgroundImage: NetworkImage(user?.photoURL ?? "https://via.placeholder.com/150"),
                        backgroundColor: const Color(0xFF18181B),
                        radius: 20,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // SLOGAN BANNER (Vercel Style Pill)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF09090B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Rent Anything • Buy Anything • Ride Anywhere",
                        style: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // CARDS LIST VIEW
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 80),
                  children: [
                    // CARD 1: RENT A CYCLE
                    _buildVercelCard(
                      context,
                      title: "Rent a Cycle",
                      subtitle: "Campus pedal-bikes for quick daily commutes",
                      tag: "CYCLES",
                      icon: Icons.pedal_bike,
                      accentColor: const Color(0xFF38BDF8),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => HomeScreen()),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // CARD 2: RENT ANYTHING
                    _buildVercelCard(
                      context,
                      title: "Rent Anything",
                      subtitle: "Electronics, sports goods, lab gear & appliances",
                      tag: "RENTAL HUB",
                      icon: Icons.inventory_2_outlined,
                      accentColor: const Color(0xFF818CF8),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ItemHomeScreen()),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // CARD 3: BUY ANYTHING
                    _buildVercelCard(
                      context,
                      title: "Buy Anything",
                      subtitle: "Peer-to-peer campus sales with instant WhatsApp contact",
                      tag: "MARKETPLACE",
                      icon: Icons.shopping_bag_outlined,
                      accentColor: const Color(0xFFFB923C),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BuyHomeScreen()),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // CARD 4: EXPLORE DESTINATIONS
                    _buildVercelCard(
                      context,
                      title: "Explore Destinations",
                      subtitle: "Popular hangouts & eateries around BPHC campus",
                      tag: "GUIDE",
                      icon: Icons.explore_outlined,
                      accentColor: const Color(0xFF34D399),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ExploreScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVercelCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String tag,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF09090B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF27272A)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, size: 26, color: accentColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          tag,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        textStyle: const TextStyle(
                          color: Color(0xFFFAFAFA),
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFA1A1AA),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: const Icon(Icons.arrow_forward, color: Color(0xFFA1A1AA), size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
