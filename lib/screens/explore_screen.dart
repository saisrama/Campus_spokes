import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:campuspks/data/explore_images.dart';
import 'package:campuspks/screens/eateries_screen.dart';
import '../theme/app_theme.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: rentXAppBar(context, "Explore Destinations", subtitle: "Ride out and discover nearby spots"),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard(context,
            title: "Grab a Bite",
            distance: "~4 kms",
            images: [eateryTaaza, eateryUdupi, eaterySereno, eateryHaveli],
            description: "Choose from cafes, South Indian, and fine dining spots around campus.",
            duration: "Explore local cuisines",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EateriesScreen())),
          ),
          const SizedBox(height: 16),
          _buildCard(context,
            title: "Shamirpet Lake",
            distance: "9 kms",
            images: [shamirpetLake1, shamirpetLake2, shamirpetLake3],
            description: "Beautiful artificial lake. Perfect for a relaxing ride and stunning sunset views.",
            duration: "Recommended: 2–3 hrs rental",
            mapLink: "https://maps.app.goo.gl/gZwMQACMzfK9JN6t7",
          ),
          const SizedBox(height: 16),
          _buildCard(context,
            title: "Shamirpet Deer Park",
            distance: "7.5 kms",
            images: [deerPark1, deerPark2],
            description: "Serene park for nature lovers. Spot deer in their natural habitat for a peaceful getaway.",
            duration: "Recommended: 2–3 hrs rental",
            mapLink: "https://maps.app.goo.gl/QnHM3AVjspUesx9x9",
          ),
          const SizedBox(height: 16),
          _buildCard(context,
            title: "Utm Lake View Point",
            distance: "11.7 kms",
            images: [utmLake1, utmLake2],
            description: "Scenic viewpoint with rocky terrain and stunning natural beauty. Great for photography.",
            duration: "Recommended: 3–4 hrs rental",
            mapLink: "https://maps.app.goo.gl/ToqZLoVZr2ApB49AA",
          ),
          const SizedBox(height: 16),
          _buildCard(context,
            title: "TSFDC Urban Forest Park",
            distance: "2 kms",
            images: [tsfdcPark],
            description: "Lush green urban forest with dedicated cycling tracks. Perfect for a refreshing ride amidst nature.",
            duration: "Recommended: 1–2 hrs rental",
            mapLink: "https://maps.app.goo.gl/Ha85ZoMxdurBctae7",
          ),
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
    String? mapLink,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ?? (mapLink != null ? () => _launchMaps(mapLink) : null),
      child: Container(
        decoration: BoxDecoration(
          color: kSurface1,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Image / Carousel
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
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(
                  onTap != null ? "View Eateries" : "View on Maps",
                  style: const TextStyle(color: kAccentCyan, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: kAccentCyan),
              ]),
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
