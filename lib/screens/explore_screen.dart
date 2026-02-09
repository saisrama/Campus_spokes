import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert'; // Import for Base64 decoding
import 'package:campuspks/data/explore_images.dart';
import 'package:campuspks/screens/eateries_screen.dart';

class ExploreScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        title: Text("Explore Destinations", style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildDestinationCard(
            context,
            title: "Grab a bite",
            distance: "~4 kms",
            images: [eateryTaaza, eateryUdupi, eaterySereno, eateryHaveli],
            description: "Choose from numerous options ranging from cafes to South Indian and fine dining around the campus.",
            duration: "Explore local cuisines",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EateriesScreen()),
              );
            },
          ),
          SizedBox(height: 24),
          _buildDestinationCard(
            context,
            title: "Shamirpet Lake",
            distance: "9 kms",
            images: [shamirpetLake1, shamirpetLake2, shamirpetLake3],
            description: "A beautiful artificial lake, perfect for a relaxing ride and sunset views. Enjoy the cool breeze and scenic water views.",
            duration: "Recommended Rental Duration: 2-3 hrs",
            mapLink: "https://maps.app.goo.gl/gZwMQACMzfK9JN6t7",
          ),
          SizedBox(height: 24),
          _buildDestinationCard(
            context,
            title: "Shamirpet Deer Park",
            distance: "7.5 kms",
            images: [deerPark1, deerPark2], // Updated to use only the two new images provided
            description: "A serene park perfect for nature lovers and spotting deer in their natural habitat. Ideal for a peaceful getaway.",
            duration: "Recommended Rental Duration: 2-3 hrs",
            mapLink: "https://maps.app.goo.gl/QnHM3AVjspUesx9x9",
          ),
          SizedBox(height: 24),
          _buildDestinationCard(
            context,
            title: "Utm Lake View Point",
            distance: "11.7 kms",
            images: [utmLake1, utmLake2],
            description: "A scenic view point overlooking the lake with rocky terrain, offering a peaceful atmosphere and stunning natural beauty. Great for photography and nature walks.",
            duration: "Recommended Rental Duration: 3-4 hrs",
            mapLink: "https://maps.app.goo.gl/ToqZLoVZr2ApB49AA",
          ),
          SizedBox(height: 24),
          _buildDestinationCard(
            context,
            title: "TSFDC Urban Forest Park",
            titleFontSize: 18, // Reduced font size to prevent clash with distance badge
            distance: "2 kms",
            images: [tsfdcPark], 
            description: "A lush green urban forest park with dedicated cycling tracks. The perfect spot for a refreshing ride amidst nature.",
            duration: "Recommended Rental Duration: 1-2 hrs",
            mapLink: "https://maps.app.goo.gl/Ha85ZoMxdurBctae7",
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationCard(
    BuildContext context, {
    required String title,
    required String distance,
    required List<String> images,
    required String description,
    required String duration,
    String? mapLink,
    double titleFontSize = 22, // Default size
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ?? (mapLink != null ? () => _launchMaps(mapLink) : null),
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 5))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SLIDESHOW
            CarouselSlider(
              options: CarouselOptions(
                height: 200.0,
                viewportFraction: 1.0, 
                enableInfiniteScroll: true,
                autoPlay: true,
              ),
              items: images.map((i) {
                return Builder(
                  builder: (BuildContext context) {
                    return Container(
                      width: MediaQuery.of(context).size.width,
                      decoration: BoxDecoration(color: Colors.black),
                      child: i.isNotEmpty 
                        ? Image.memory(
                            base64Decode(i),
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, size: 50, color: Colors.white24),
                                  SizedBox(height: 8),
                                  Text("Invalid Base64", style: TextStyle(color: Colors.white24, fontSize: 10))
                                ],
                              )
                            ),
                          )
                        : Center(child: Icon(Icons.image_not_supported, color: Colors.white24, size: 50)),
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
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: titleFontSize, // Use dynamic font size
                            fontWeight: FontWeight.bold, 
                            color: Colors.white
                          ),
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
                            Text(distance, style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.access_time_filled, size: 16, color: Colors.orange),
                      SizedBox(width: 6),
                      Text(
                        duration,
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        onTap != null ? "View Eateries" : "View on Maps", 
                        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)
                      ),
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

  Future<void> _launchMaps(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }
}
