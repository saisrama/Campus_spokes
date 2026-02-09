import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../data/explore_images.dart';

class EateriesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          "Eateries Around Campus",
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildEateryDestinationCard(
            context,
            title: "Tandoor Restaurant",
            distance: "3.7 kms",
            images: [eateryTandoor],
            description: "Known for its rich and flavorful Tandoori dishes and diverse multi-cuisine menu. A great spot for a hearty meal with friends.",
            duration: "Recommended Rental Duration: 2 hrs",
            priceInfo: "Price for two: ~₹600",
            mapLink: "https://maps.app.goo.gl/5fFHXuaevAHBc8bY7",
          ),
          SizedBox(height: 24),
          _buildEateryDestinationCard(
            context,
            title: "Hotel Shree Krishna Udupi",
            titleFontSize: 18, // Reduced font size to prevent clash with distance badge
            distance: "3.7 kms",
            images: [eateryUdupi],
            description: "Known for its authentic South Indian vegetarian cuisine, offering a variety of dossas, idlis, and thalis. A perfect spot for a quick and delicious breakfast or lunch.",
            duration: "Recommended Rental Duration: 2 hrs",
            priceInfo: "Price for two: ~₹200", // User updated this previously
            mapLink: "https://maps.app.goo.gl/81WFt2yXqjDjbgbm6",
          ),
          SizedBox(height: 24),
          _buildEateryDestinationCard(
            context,
            title: "Bits and Bytes",
            distance: "4.3 kms",
            images: [eateryBitsBytes],
            description: "A popular coffee shop and bakery offering a cozy ambiance. Enjoy a variety of pizzas, sandwiches, thick shakes, and freshly baked pastries.",
            duration: "Recommended Rental Duration: 2 hrs",
            priceInfo: "Price for two: ~₹600",
            mapLink: "https://maps.app.goo.gl/nhrWCfc12a2kCQTq7",
          ),
          SizedBox(height: 24),
          _buildEateryDestinationCard(
            context,
            title: "Taaza",
            distance: "4.5 kms",
            images: [eateryTaaza],
            description: "A popular spot for all-day breakfast, serving fresh and hot South Indian tiffins like idlis, vadas, and dosas in a hygienic setting.",
            duration: "Recommended Rental Duration: 2 hrs",
            priceInfo: "Price for two: ~₹400",
            mapLink: "https://maps.app.goo.gl/Ens9dVZtf34u6ous9",
          ),
          SizedBox(height: 24),
          _buildEateryDestinationCard(
            context,
            title: "Katha Kitchen",
            distance: "4.5 kms",
            images: [eateryKatha],
            description: "A cozy spot offering all-day breakfast, lunch, and snacks. Perfect for enjoying authentic South Indian meals and tiffins with friends.",
            duration: "Recommended Rental Duration: 2 hrs",
            priceInfo: "Price for two: ~₹400",
            mapLink: "https://maps.app.goo.gl/ermsZTYb8FxXGjxG9",
          ),
          SizedBox(height: 24),
          _buildEateryDestinationCard(
            context,
            title: "Punjabi Haveli Dhaba",
            distance: "4.3 kms",
            images: [eateryHaveli],
            description: "Authentic Punjabi dhaba with a vibrant atmosphere, featuring unique truck decor and traditional cot seating. Famous for its tandoori kulchas and Bahubali lassi.",
            duration: "Recommended Rental Duration: 2 hrs",
            priceInfo: "Price for two: ~₹1000",
            mapLink: "https://maps.app.goo.gl/aYqwDLKwk31nsgy78",
          ),
          SizedBox(height: 24),
          _buildEateryDestinationCard(
            context,
            title: "Sereno Cafe",
            distance: "4.4 kms",
            images: [eaterySereno],
            description: "An elegant cafe blending tradition with innovation. Offers a cozy yet refined atmosphere perfect for coffee, quick bites, and extended gatherings.",
            duration: "Recommended Rental Duration: 2 hrs",
            priceInfo: "Price for two: ~₹800",
            mapLink: "https://maps.app.goo.gl/wATTZRRQgSUm3Cv4A",
          ),
          SizedBox(height: 24),
          _buildEateryDestinationCard(
            context,
            title: "Aalankrita",
            distance: "4.3 kms",
            images: [eateryAalankrita],
            description: "Experience fine dining at its best with multi-cuisine options and a luxurious ambiance. Perfect for special occasions and enjoying a premium meal.",
            duration: "Recommended Rental Duration: 2 hrs",
            priceInfo: "Price for two: ~₹1200",
            mapLink: "https://maps.app.goo.gl/Q3BL3w4W213a1PyP9", 
          ),
        ],
      ),
    );
  }

  Widget _buildEateryDestinationCard(
    BuildContext context, {
    required String title,
    required String distance,
    required List<String> images,
    required String description,
    required String duration,
    required String priceInfo,
    String? mapLink,
    double titleFontSize = 22, // Default size
  }) {
    return GestureDetector(
      onTap: mapLink != null ? () => _launchMaps(mapLink) : null,
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
                      Expanded( // Added Expanded to text to prevent overflow
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: titleFontSize, // Use the dynamic font size
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
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.currency_rupee, size: 16, color: Colors.green), // Changed icon to currency
                      SizedBox(width: 6),
                      Text(
                        priceInfo,
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        "View on Maps", 
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
