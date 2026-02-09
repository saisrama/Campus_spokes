import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import 'explore_screen.dart';
import 'add_cycle_screen.dart'; // Add import

class LandingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212), // Dark background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Align header to left? User said "top let there be the campus spokes logo and the campus spokes written next to in the Medula one font"
            children: [
              // HEADER
              Row(
                children: [
                  Image.asset('assets/images/logo.png', height: 40), // Adjust height as needed
                  SizedBox(width: 12),
                  Text(
                    "Campus Spokes",
                    style: GoogleFonts.medulaOne(
                      textStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 36, // Medula One is condensed, so larger size is good
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
              
              Spacer(), // Push cards to center or just space them out? Center seems cleaner.

              // CARD 1: RENT A CYCLE
              _buildLandingCard(
                context,
                title: "Rent a cycle",
                icon: Icons.pedal_bike,
                color: Colors.blueAccent,
                onTap: () => Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => HomeScreen())
                ),
              ),

              SizedBox(height: 24), // Spacing between cards

              // CARD 2: LIST MY CYCLE (New)
              _buildLandingCard(
                context,
                title: "List my cycle",
                icon: Icons.add_circle_outline,
                color: Colors.orangeAccent,
                onTap: () => Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => AddCycleScreen())
                ),
              ),

              SizedBox(height: 24),

              // CARD 3: EXPLORE DESTINATIONS
              _buildLandingCard(
                context,
                title: "Explore destinations from campus",
                icon: Icons.explore,
                color: Colors.greenAccent,
                onTap: () => Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => ExploreScreen())
                ),
              ),

              Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLandingCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          height: 160,
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Color(0xFF1E1E1E), // Slightly lighter dark
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
              Icon(icon, size: 40, color: color),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: GoogleFonts.poppins( // Using a clean sans-serif for body
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
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
