import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

class ExploreScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        title: Text("Explore Destinations", style: GoogleFonts.poppins()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildDestinationCard(context),
        ],
      ),
    );
  }

  Widget _buildDestinationCard(BuildContext context) {
    // Placeholder images - User should replace these with actual asset paths or URLs
    final List<String> imgList = [
      'https://lh5.googleusercontent.com/p/AF1QipMKjYkKo7o0-0-0-0-0-0-0-0-0-0-0-0-0-0-0-0-0-0-0-0', // Lake view
      'https://lh5.googleusercontent.com/p/AF1QipN3-0-0-0-0-0-0-0-0-0-0-0-0-0-0-0-0-0-0-0-0', // Sunset
      'https://lh5.googleusercontent.com/p/AF1QipO-0-0-0-0-0-0-0-0-0-0-0-0-0-0-0-0-0-0-0-0', // Road
    ];

    return GestureDetector(
      onTap: _launchMaps,
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 5))],
        ),
        clipBehavior: Clip.antiAlias, // Clips the image to border radius
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SLIDESHOW
            CarouselSlider(
              options: CarouselOptions(
                height: 200.0,
                viewportFraction: 1.0, // Full width
                enableInfiniteScroll: true,
                autoPlay: true,
              ),
              items: imgList.map((i) {
                return Builder(
                  builder: (BuildContext context) {
                    return Container(
                      width: MediaQuery.of(context).size.width,
                      decoration: BoxDecoration(color: Colors.grey),
                      child: Image.network(
                        i,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Center(
                          child: Icon(Icons.image, size: 50, color: Colors.white24)
                        ), // Fallback
                      ),
                    );
                  },
                );
              }).toList(),
            ),

            // DETAILS
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Shamirpet Lake",
                        style: GoogleFonts.poppins(
                          fontSize: 22, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.white
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blueAccent.withOpacity(0.5))
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.directions_bike, size: 16, color: Colors.blueAccent),
                            SizedBox(width: 4),
                            Text("9 kms", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    "A serene getaway perfect for a morning ride. Enjoy the cool breeze, scenic water views, and a smooth route ideal for cycling enthusiasts from campus.",
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.access_time_filled, size: 16, color: Colors.orange),
                      SizedBox(width: 6),
                      Text(
                        "Recommended rental duration: 2 hrs",
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text("View on Maps", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      Icon(Icons.arrow_forward, size: 16, color: Colors.blue),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchMaps() async {
    final Uri url = Uri.parse('https://maps.app.goo.gl/gZwMQACMzfK9JN6t7');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }
}
