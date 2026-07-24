import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../data/explore_images.dart';
import '../theme/app_theme.dart';

class EateriesScreen extends StatelessWidget {
  const EateriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: rentXAppBar(context, "Eateries Around Campus", subtitle: "Find great spots to eat nearby"),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard(context, title: "Tandoor Restaurant", distance: "3.7 kms", images: [eateryTandoor], description: "Known for its rich Tandoori dishes and diverse multi-cuisine menu. A great spot for a hearty meal.", duration: "Recommended: 2 hrs rental", priceInfo: "~₹600 for two", mapLink: "https://maps.app.goo.gl/5fFHXuaevAHBc8bY7"),
          const SizedBox(height: 16),
          _buildCard(context, title: "Hotel Shree Krishna Udupi", distance: "3.7 kms", images: [eateryUdupi], description: "Authentic South Indian vegetarian cuisine — dosas, idlis, and thalis. Quick and delicious.", duration: "Recommended: 2 hrs rental", priceInfo: "~₹200 for two", mapLink: "https://maps.app.goo.gl/81WFt2yXqjDjbgbm6"),
          const SizedBox(height: 16),
          _buildCard(context, title: "Bits and Bytes", distance: "4.3 kms", images: [eateryBitsBytes], description: "Coffee shop & bakery with cozy ambiance. Pizzas, sandwiches, thick shakes, and freshly baked pastries.", duration: "Recommended: 2 hrs rental", priceInfo: "~₹600 for two", mapLink: "https://maps.app.goo.gl/nhrWCfc12a2kCQTq7"),
          const SizedBox(height: 16),
          _buildCard(context, title: "Taaza", distance: "4.5 kms", images: [eateryTaaza], description: "Popular all-day breakfast spot — fresh South Indian tiffins: idlis, vadas, and dosas.", duration: "Recommended: 2 hrs rental", priceInfo: "~₹400 for two", mapLink: "https://maps.app.goo.gl/Ens9dVZtf34u6ous9"),
          const SizedBox(height: 16),
          _buildCard(context, title: "Katha Kitchen", distance: "4.5 kms", images: [eateryKatha], description: "Cozy all-day spot with authentic South Indian meals and tiffins.", duration: "Recommended: 2 hrs rental", priceInfo: "~₹400 for two", mapLink: "https://maps.app.goo.gl/ermsZTYb8FxXGjxG9"),
          const SizedBox(height: 16),
          _buildCard(context, title: "Punjabi Haveli Dhaba", distance: "4.3 kms", images: [eateryHaveli], description: "Authentic Punjabi dhaba — tandoori kulchas and Bahubali lassi in a vibrant truck-decor setting.", duration: "Recommended: 2 hrs rental", priceInfo: "~₹1000 for two", mapLink: "https://maps.app.goo.gl/aYqwDLKwk31nsgy78"),
          const SizedBox(height: 16),
          _buildCard(context, title: "Sereno Cafe", distance: "4.4 kms", images: [eaterySereno], description: "Elegant cafe — cozy yet refined. Perfect for coffee, quick bites, and extended gatherings.", duration: "Recommended: 2 hrs rental", priceInfo: "~₹800 for two", mapLink: "https://maps.app.goo.gl/wATTZRRQgSUm3Cv4A"),
          const SizedBox(height: 16),
          _buildCard(context, title: "Aalankrita", distance: "4.3 kms", images: [eateryAalankrita], description: "Fine dining with multi-cuisine options and luxurious ambiance. Great for special occasions.", duration: "Recommended: 2 hrs rental", priceInfo: "~₹1200 for two", mapLink: "https://maps.app.goo.gl/Q3BL3w4W213a1PyP9"),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, {
    required String title,
    required String distance,
    required List<String> images,
    required String description,
    required String duration,
    required String priceInfo,
    String? mapLink,
  }) {
    return GestureDetector(
      onTap: mapLink != null ? () => _launchMaps(mapLink) : null,
      child: Container(
        decoration: BoxDecoration(
          color: kSurface1,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Image
          if (images.length > 1)
            CarouselSlider(
              options: CarouselOptions(height: 200, viewportFraction: 1.0, enableInfiniteScroll: true, autoPlay: true),
              items: images.map((i) => _imageWidget(i)).toList(),
            )
          else
            SizedBox(height: 200, width: double.infinity, child: _imageWidget(images.isNotEmpty ? images.first : '')),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(title, style: GoogleFonts.inter(color: kTextPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                rentXBadge(distance, color: kAccentCyan),
              ]),
              const SizedBox(height: 8),
              Text(description, style: const TextStyle(color: kTextMuted, fontSize: 13, height: 1.5)),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.access_time_rounded, size: 14, color: kAccentOrange),
                const SizedBox(width: 6),
                Text(duration, style: const TextStyle(color: kAccentOrange, fontWeight: FontWeight.w600, fontSize: 12)),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.currency_rupee_rounded, size: 14, color: kAccentGreen),
                const SizedBox(width: 6),
                Text(priceInfo, style: const TextStyle(color: kAccentGreen, fontWeight: FontWeight.w600, fontSize: 12)),
              ]),
              if (mapLink != null) ...[
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text("View on Maps", style: TextStyle(color: kAccentCyan, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: kAccentCyan),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _imageWidget(String base64) {
    if (base64.isEmpty) return const Center(child: Icon(Icons.image_not_supported_outlined, color: kTextDim, size: 40));
    return Image.memory(
      base64Decode(base64),
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image_outlined, size: 40, color: kTextDim)),
    );
  }

  Future<void> _launchMaps(String urlString) async {
    final Uri url = Uri.parse(urlString);
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
