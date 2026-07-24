import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final msg = "Hi ${widget.data['ownerName']}, I'm interested in buying your \"$itemName\" listed for ₹$price on Campus Spokes. Can we arrange collection at $location Bhavan?";

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
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Rate This Seller", style: TextStyle(color: Colors.white)),
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
              TextField(
                controller: _reviewController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: "Share your experience...", hintStyle: TextStyle(color: Colors.grey)),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Skip", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('sale_items').doc(widget.itemId).collection('reviews').add({
                  'userId': currentUser?.uid,
                  'userName': currentUser?.displayName ?? 'Anonymous',
                  'rating': _selectedRating,
                  'comment': _reviewController.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(context);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thank you for your review!")));
              },
              child: const Text("Submit", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(height: 280, color: Colors.grey[900], child: const Icon(Icons.inventory_2, size: 80, color: Colors.white24));
    }
    if (imageUrl.startsWith('http')) return Image.network(imageUrl, height: 280, width: double.infinity, fit: BoxFit.cover);
    try { return Image.memory(base64Decode(imageUrl), height: 280, width: double.infinity, fit: BoxFit.cover); } catch (_) {
      return Container(height: 280, color: Colors.grey[900], child: const Icon(Icons.broken_image, size: 80, color: Colors.white24));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSold = widget.data['isSold'] == true;
    final isOwner = currentUser?.uid == widget.data['ownerId'];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(widget.data['itemName'] ?? 'Item'),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          if (isOwner)
            IconButton(
              icon: Icon(isSold ? Icons.undo : Icons.check_circle, color: isSold ? Colors.grey : Colors.green),
              tooltip: isSold ? "Mark as Available" : "Mark as Sold",
              onPressed: () async {
                await FirebaseFirestore.instance.collection('sale_items').doc(widget.itemId).update({'isSold': !isSold});
                if (mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(
        children: [
          Stack(
            children: [
              _buildImage(widget.data['imageUrl']),
              if (isSold)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: const Center(child: Text("SOLD", style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 8))),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(widget.data['itemName'] ?? 'Item', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(16)),
                      child: Text("₹${widget.data['price'] ?? 0}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                    child: Text(widget.data['itemType'] ?? 'General', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5))),
                    child: Text(widget.data['condition'] ?? 'Good', style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.location_on, color: Colors.orangeAccent, size: 16),
                  const SizedBox(width: 6),
                  Text("Collect From: ${widget.data['location'] ?? 'Campus'} Bhavan (Room ${widget.data['roomNumber'] ?? 'N/A'})", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.person, color: Colors.orangeAccent, size: 16),
                  const SizedBox(width: 6),
                  Text("Seller: ${widget.data['ownerName'] ?? 'Student'}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
                const Divider(color: Colors.white24, height: 32),

                if ((widget.data['description'] ?? '').isNotEmpty) ...[
                  const Text("Description", style: TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(widget.data['description'], style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const Divider(color: Colors.white24, height: 32),
                ],

                if (!isSold) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.chat, color: Colors.white),
                      label: const Text("Contact Seller via WhatsApp", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _contactSeller,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.star, color: Colors.orangeAccent),
                      label: const Text("Rate This Seller", style: TextStyle(color: Colors.orangeAccent)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.orangeAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _showReviewDialog,
                    ),
                  ),
                ] else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withValues(alpha: 0.3))),
                    child: const Center(child: Text("This item has been sold.", style: TextStyle(color: Colors.grey, fontSize: 15))),
                  ),

                const SizedBox(height: 24),
                const Text("Reviews", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('sale_items').doc(widget.itemId).collection('reviews').orderBy('createdAt', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator(color: Colors.orangeAccent);
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Text("No reviews yet.", style: TextStyle(color: Colors.grey));
                    return ListView.builder(
                      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var rev = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(rev['userName'] ?? 'Anonymous', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Row(children: List.generate(5, (i) => Icon(i < (rev['rating'] ?? 5) ? Icons.star : Icons.star_border, color: Colors.amber, size: 14))),
                            ]),
                            if ((rev['comment'] ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(rev['comment'], style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            ]
                          ]),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
