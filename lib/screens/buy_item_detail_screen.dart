import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_image_viewer.dart';

class BuyItemDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String itemId;

  const BuyItemDetailScreen({super.key, required this.data, required this.itemId});

  @override
  State<BuyItemDetailScreen> createState() => _BuyItemDetailScreenState();
}

class _BuyItemDetailScreenState extends State<BuyItemDetailScreen> {
  User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _reviewController = TextEditingController();
  int _selectedRating = 5;
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  List<String> get _allImageUrls {
    if (widget.data['imageUrls'] is List && (widget.data['imageUrls'] as List).isNotEmpty) {
      return List<String>.from(widget.data['imageUrls']);
    }
    if ((widget.data['imageUrl'] ?? '').isNotEmpty) {
      return [widget.data['imageUrl']];
    }
    return [];
  }

  Future<void> _contactSeller() async {
    String phone = widget.data['ownerPhone'] ?? '';
    if (phone.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Seller phone not provided")));
      return;
    }
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!cleanPhone.startsWith('91') && cleanPhone.length == 10) cleanPhone = '91$cleanPhone';

    final itemName = widget.data['itemName'] ?? 'item';
    final price = widget.data['price'] ?? 0;
    final location = widget.data['location'] ?? 'campus';
    final msg = "Hi ${widget.data['ownerName']}, I'm interested in buying your \"$itemName\" listed for ₹$price on RentX. Can we arrange collection at $location Bhavan?";

    final Uri url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(msg)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch WhatsApp")));
    }
  }

  void _showReviewDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: kSurface1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: kBorder)),
          title: const Text("Rate This Seller", style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(index < _selectedRating ? Icons.star : Icons.star_border, color: Colors.amber, size: 32),
                    onPressed: () => setDialogState(() => _selectedRating = index + 1),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reviewController,
                style: const TextStyle(color: kTextPrimary),
                decoration: rentXInputDecoration("Review", hint: "Share your experience with seller..."),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Skip", style: TextStyle(color: kTextDim))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kTextPrimary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('sale_items').doc(widget.itemId).collection('reviews').add({
                  'userId': currentUser?.uid,
                  'userName': currentUser?.displayName ?? 'Anonymous',
                  'rating': _selectedRating,
                  'comment': _reviewController.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(context);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thank you for your review!"), backgroundColor: kSurface1));
              },
              child: const Text("Submit", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreenViewer(int initialIndex) {
    final urls = _allImageUrls;
    if (urls.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(imageUrls: urls, initialIndex: initialIndex),
      ),
    );
  }

  Widget _buildSingleImage(String url, int index) {
    Widget img;
    if (url.startsWith('http')) {
      img = Image.network(url, height: 280, width: double.infinity, fit: BoxFit.cover);
    } else {
      try {
        img = Image.memory(base64Decode(url), height: 280, width: double.infinity, fit: BoxFit.cover);
      } catch (_) {
        img = Container(height: 280, color: kSurface1, child: const Icon(Icons.broken_image, size: 80, color: kTextDim));
      }
    }
    return GestureDetector(
      onTap: () => _openFullScreenViewer(index),
      child: img,
    );
  }

  Widget _buildImageGallery() {
    final urls = _allImageUrls;
    if (urls.isEmpty) {
      return Container(
        height: 260,
        color: kSurface1,
        child: const Center(child: Icon(Icons.shopping_bag_outlined, size: 60, color: kTextDim)),
      );
    }

    if (urls.length == 1) {
      return _buildSingleImage(urls.first, 0);
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: 280,
          child: PageView.builder(
            controller: _pageController,
            itemCount: urls.length,
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemBuilder: (context, index) => _buildSingleImage(urls[index], index),
          ),
        ),
        Positioned(
          bottom: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: urls.asMap().entries.map((entry) {
              return Container(
                width: _currentImageIndex == entry.key ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: _currentImageIndex == entry.key ? kTextPrimary : kTextPrimary.withValues(alpha: 0.4),
                ),
              );
            }).toList(),
          ),
        ),
        Positioned(
          top: 12, right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(12)),
            child: Text("${_currentImageIndex + 1}/${urls.length}", style: const TextStyle(color: kTextPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemName = widget.data['itemName'] ?? 'Item Details';
    final price = widget.data['price'] ?? 0;
    final itemType = widget.data['itemType'] ?? 'General';
    final location = widget.data['location'] ?? 'Campus';
    final ownerName = widget.data['ownerName'] ?? 'Seller';
    final roomNumber = widget.data['roomNumber'] ?? 'N/A';
    final description = widget.data['description'] ?? 'No description provided.';
    final condition = widget.data['condition'] ?? 'Good';
    final isOwner = currentUser != null && currentUser!.uid == widget.data['ownerId'];

    return Scaffold(
      backgroundColor: kBgColor,
      appBar: rentXAppBar(context, itemName, subtitle: "Buy Section • $itemType"),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageGallery(),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(itemName, style: const TextStyle(color: kTextPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("Seller: $ownerName • Room $roomNumber, $location Bhavan", style: const TextStyle(color: kTextMuted, fontSize: 13)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("₹$price", style: const TextStyle(color: kAccentOrange, fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          rentXBadge(condition, color: kAccentOrange),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  rentXSectionLabel("DETAILS"),
                  rentXCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, color: kTextMuted, size: 16),
                            const SizedBox(width: 6),
                            Text("Collect from: $location Bhavan (Room $roomNumber)", style: const TextStyle(color: kTextPrimary, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.category_outlined, color: kTextMuted, size: 16),
                            const SizedBox(width: 6),
                            Text("Category: $itemType", style: const TextStyle(color: kTextPrimary, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  rentXSectionLabel("DESCRIPTION"),
                  rentXCard(
                    padding: const EdgeInsets.all(14),
                    child: Text(description, style: const TextStyle(color: kTextMuted, fontSize: 13, height: 1.5)),
                  ),
                  const SizedBox(height: 24),

                  if (isOwner) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: kSurface1, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
                      child: const Center(child: Text("This is your sale listing", style: TextStyle(color: kTextMuted, fontSize: 13))),
                    ),
                  ] else ...[
                    rentXButton(
                      label: "BUY NOW — CONTACT SELLER",
                      onTap: _contactSeller,
                      color: kAccentGreen,
                      icon: Icons.chat_bubble_outline,
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
