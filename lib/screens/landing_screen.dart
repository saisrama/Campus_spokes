import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import 'item_home_screen.dart';
import 'explore_screen.dart';
import 'add_cycle_screen.dart';
import 'add_item_screen.dart';
import 'buy_home_screen.dart';
import 'add_sale_item_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';

class LandingScreen extends StatelessWidget {
  final User? user = FirebaseAuth.instance.currentUser;

  void _showListOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Select Listing Type", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.pedal_bike, color: Colors.blueAccent),
                ),
                title: Text("List My Cycle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text("List a cycle for other students to rent", style: TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AddCycleScreen()));
                },
              ),
              Divider(color: Colors.white12),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.inventory_2_outlined, color: Colors.indigoAccent),
                ),
                title: Text("List an Item (Rent Anything)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text("List electronics, sports goods, tools, books, etc.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AddItemScreen()));
                },
              ),
              Divider(color: Colors.white12),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.sell_outlined, color: Colors.orangeAccent),
                ),
                title: Text("Sell an Item", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text("List an item for sale", style: TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AddSaleItemScreen()));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showListOptions(context),
        label: Text("List Item / Cycle"),
        icon: Icon(Icons.add),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/images/logo.png', height: 40),
                      SizedBox(width: 12),
                      Text(
                        "Campus Spokes",
                        style: GoogleFonts.medulaOne(
                          textStyle: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Profile Avatar
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen())),
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(user?.photoURL ?? "https://via.placeholder.com/150"),
                      backgroundColor: Colors.grey,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24),

              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(bottom: 24),
                  children: [
                    // CARD 1: RENT A CYCLE
                    _buildLandingCard(
                      context,
                      title: "Rent a cycle",
                      icon: Icons.pedal_bike,
                      color: Colors.blueAccent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => HomeScreen()),
                      ),
                    ),
                    SizedBox(height: 20),

                    // CARD 2: RENT ANYTHING
                    _buildLandingCard(
                      context,
                      title: "Rent Anything (Electronics, Sports, etc.)",
                      icon: Icons.inventory_2_outlined,
                      color: Colors.indigoAccent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ItemHomeScreen()),
                      ),
                    ),
                    SizedBox(height: 20),

                    // CARD 3: BUY ANYTHING
                    _buildLandingCard(
                      context,
                      title: "Buy Anything (Electronics, Books, etc.)",
                      icon: Icons.shopping_bag_outlined,
                      color: Colors.orangeAccent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => BuyHomeScreen()),
                      ),
                    ),
                    SizedBox(height: 20),

                    // CARD 4: EXPLORE DESTINATIONS
                    _buildLandingCard(
                      context,
                      title: "Explore destinations from campus",
                      icon: Icons.explore,
                      color: Colors.greenAccent,
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

  Widget _buildLandingCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          height: 140,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 36, color: color),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: GoogleFonts.poppins(
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
