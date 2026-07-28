import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import 'add_cycle_screen.dart';
import 'add_item_screen.dart';
import 'add_sale_item_screen.dart';
import 'cycle_history_screen.dart';

class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: kBgColor,
        appBar: AppBar(
          backgroundColor: kBgColor,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: kTextPrimary),
          title: const Text("My Listings", style: TextStyle(fontWeight: FontWeight.bold, color: kTextPrimary, fontSize: 18, letterSpacing: -0.3)),
          bottom: const TabBar(
            indicatorColor: kTextPrimary,
            labelColor: kTextPrimary,
            unselectedLabelColor: kTextDim,
            tabs: [
              Tab(icon: Icon(Icons.pedal_bike_outlined, size: 18), text: "Cycles"),
              Tab(icon: Icon(Icons.inventory_2_outlined, size: 18), text: "Items"),
              Tab(icon: Icon(Icons.sell_outlined, size: 18), text: "Sales"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCyclesTab(context, user),
            _buildItemsTab(context, user),
            _buildSalesTab(context, user),
          ],
        ),
      ),
    );
  }

  Widget _buildCyclesTab(BuildContext context, User? user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cycles')
          .where('ownerId', isEqualTo: user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kTextPrimary, strokeWidth: 2));
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: kAccentRed)));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return rentXEmptyState(
            icon: Icons.pedal_bike_outlined,
            message: "No cycles listed yet",
            subMessage: "List your cycle and start earning from rentals.",
            action: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddCycleScreen())),
              style: ElevatedButton.styleFrom(backgroundColor: kTextPrimary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              child: const Text("List a Cycle", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
        }
        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['createdAt'] != null ? (aData['createdAt'] as Timestamp).toDate() : DateTime(2000);
            final bTime = bData['createdAt'] != null ? (bData['createdAt'] as Timestamp).toDate() : DateTime(2000);
            return bTime.compareTo(aTime);
          });
        return Column(
          children: [
            // Add cycle button at the top
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddCycleScreen())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("List a New Cycle", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final cycleId = docs[index].id;
                  final bool ownerDisabled = data['ownerDisabled'] ?? false;
                  return _listingCard(
                    context: context,
                    imageUrl: data['imageUrl'] ?? '',
                    title: "${data['modelName']} – ${data['gearType'] ?? 'Single Geared'}",
                    subtitle: "₹${data['basePrice']} / 2hrs  •  ${data['location']}",
                    ownerDisabled: ownerDisabled,
                    isSold: false,
                    onToggle: (val) => FirebaseFirestore.instance.collection('cycles').doc(cycleId).update({'ownerDisabled': !val}),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CycleHistoryScreen(cycleId: cycleId, cycleData: data))),
                    actions: [
                      _actionBtn(icon: Icons.comment_outlined, label: "Reviews", color: kAccentAmber, onTap: () => _showReviews(context, cycleId, isItem: false)),
                      _actionBtn(icon: Icons.edit_outlined, label: "Edit", color: kAccentCyan, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddCycleScreen(cycleData: data, cycleId: cycleId)))),
                      _actionBtn(icon: Icons.delete_outline, label: "Delete", color: kAccentRed, onTap: () => _confirmDelete(context, cycleId, collection: 'cycles')),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildItemsTab(BuildContext context, User? user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('items')
          .where('ownerId', isEqualTo: user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kTextPrimary, strokeWidth: 2));
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: kAccentRed)));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return rentXEmptyState(
            icon: Icons.inventory_2_outlined,
            message: "No items listed yet",
            subMessage: "List items for rent and let students borrow from you.",
            action: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddItemScreen())),
              style: ElevatedButton.styleFrom(backgroundColor: kTextPrimary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              child: const Text("List an Item", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
        }
        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['createdAt'] != null ? (aData['createdAt'] as Timestamp).toDate() : DateTime(2000);
            final bTime = bData['createdAt'] != null ? (bData['createdAt'] as Timestamp).toDate() : DateTime(2000);
            return bTime.compareTo(aTime);
          });
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final itemId = docs[index].id;
            final bool ownerDisabled = data['ownerDisabled'] ?? false;
            final String itemName = data['itemName'] ?? 'Item';
            final String itemType = data['itemType'] ?? 'General';
            final String location = data['location'] ?? 'Campus';
            return _listingCard(
              context: context,
              imageUrl: data['imageUrl'] ?? '',
              title: "$itemName – $itemType",
              subtitle: "₹${data['basePrice']} / 2hrs  •  Collect: $location Bhavan",
              ownerDisabled: ownerDisabled,
              isSold: false,
              onToggle: (val) => FirebaseFirestore.instance.collection('items').doc(itemId).update({'ownerDisabled': !val}),
              onTap: null,
              actions: [
                _actionBtn(icon: Icons.comment_outlined, label: "Reviews", color: kAccentAmber, onTap: () => _showReviews(context, itemId, isItem: true)),
                _actionBtn(icon: Icons.edit_outlined, label: "Edit", color: kAccentCyan, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddItemScreen(itemData: data, itemId: itemId)))),
                _actionBtn(icon: Icons.delete_outline, label: "Delete", color: kAccentRed, onTap: () => _confirmDelete(context, itemId, collection: 'items')),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSalesTab(BuildContext context, User? user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sale_items')
          .where('ownerId', isEqualTo: user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kTextPrimary, strokeWidth: 2));
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: kAccentRed)));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return rentXEmptyState(
            icon: Icons.sell_outlined,
            message: "No sale items listed yet",
            subMessage: "Sell your old stuff to fellow students.",
            action: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddSaleItemScreen())),
              style: ElevatedButton.styleFrom(backgroundColor: kTextPrimary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              child: const Text("Sell an Item", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
        }
        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['createdAt'] != null ? (aData['createdAt'] as Timestamp).toDate() : DateTime(2000);
            final bTime = bData['createdAt'] != null ? (bData['createdAt'] as Timestamp).toDate() : DateTime(2000);
            return bTime.compareTo(aTime);
          });
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final itemId = docs[index].id;
            final bool ownerDisabled = data['ownerDisabled'] ?? false;
            final bool isSold = data['isSold'] ?? false;
            final String itemName = data['itemName'] ?? 'Item';
            final String itemType = data['itemType'] ?? 'General';
            final int price = data['price'] ?? 0;
            return _listingCard(
              context: context,
              imageUrl: data['imageUrl'] ?? '',
              title: "$itemName – $itemType",
              subtitle: "₹$price  •  Condition: ${data['condition'] ?? 'Good'}",
              ownerDisabled: ownerDisabled,
              isSold: isSold,
              onToggle: (val) => FirebaseFirestore.instance.collection('sale_items').doc(itemId).update({'ownerDisabled': !val}),
              onTap: null,
              actions: [
                _actionBtn(
                  icon: isSold ? Icons.undo_rounded : Icons.check_circle_outline,
                  label: isSold ? "Available" : "Mark Sold",
                  color: isSold ? kTextMuted : kAccentGreen,
                  onTap: () => FirebaseFirestore.instance.collection('sale_items').doc(itemId).update({'isSold': !isSold}),
                ),
                _actionBtn(icon: Icons.edit_outlined, label: "Edit", color: kAccentCyan, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddSaleItemScreen(itemData: data, itemId: itemId)))),
                _actionBtn(icon: Icons.delete_outline, label: "Delete", color: kAccentRed, onTap: () => _confirmDelete(context, itemId, collection: 'sale_items')),
              ],
            );
          },
        );
      },
    );
  }

  Widget _listingCard({
    required BuildContext context,
    required String imageUrl,
    required String title,
    required String subtitle,
    required bool ownerDisabled,
    required bool isSold,
    required Function(bool) onToggle,
    required VoidCallback? onTap,
    required List<Widget> actions,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: kSurface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(children: [
        InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildImage(imageUrl, width: 64, height: 64),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextPrimary))),
                  if (isSold) rentXBadge("SOLD", color: kAccentRed),
                ]),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: kTextMuted, fontSize: 12)),
              ])),
              Switch(
                value: !ownerDisabled,
                activeThumbColor: kAccentGreen,
                inactiveThumbColor: kTextDim,
                inactiveTrackColor: kSurface2,
                onChanged: onToggle,
              ),
            ]),
          ),
        ),
        Container(height: 1, color: kBorder),
        if (ownerDisabled)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: kAccentAmber.withValues(alpha: 0.08),
            child: const Text("Currently Delisted — hidden from feed", textAlign: TextAlign.center, style: TextStyle(color: kAccentAmber, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: actions),
        ),
      ]),
    );
  }

  Widget _actionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return TextButton.icon(
      icon: Icon(icon, color: color, size: 16),
      label: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      onPressed: onTap,
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
    );
  }

  void _confirmDelete(BuildContext context, String docId, {required String collection}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: kBorder)),
        title: const Text("Delete Listing?", style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold)),
        content: const Text("This action cannot be undone.", style: TextStyle(color: kTextMuted)),
        actions: [
          TextButton(child: const Text("Cancel", style: TextStyle(color: kTextDim)), onPressed: () => Navigator.pop(context)),
          TextButton(
            child: const Text("Delete", style: TextStyle(color: kAccentRed, fontWeight: FontWeight.bold)),
            onPressed: () {
              FirebaseFirestore.instance.collection(collection).doc(docId).delete();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String? imageUrl, {double? width, double? height}) {
    final Widget placeholder = Container(
      width: width, height: height,
      color: kSurface2,
      child: const Center(child: Icon(Icons.inventory_2_outlined, size: 28, color: kTextDim)),
    );

    if (imageUrl == null || imageUrl.isEmpty) return placeholder;

    if (imageUrl.startsWith('http')) {
      return Image.network(imageUrl, width: width, height: height, fit: BoxFit.cover, errorBuilder: (e, s, t) => placeholder);
    }

    try {
      return Image.memory(base64Decode(imageUrl), width: width, height: height, fit: BoxFit.cover, errorBuilder: (e, s, t) => placeholder);
    } catch (e) {
      return placeholder;
    }
  }

  void _showReviews(BuildContext context, String targetId, {required bool isItem}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Icon(Icons.star_rounded, color: kAccentAmber, size: 20),
                const SizedBox(width: 8),
                const Text("Reviews", style: TextStyle(color: kTextPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 14),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: isItem
                      ? FirebaseFirestore.instance.collection('items').doc(targetId).collection('reviews').orderBy('createdAt', descending: true).snapshots()
                      : FirebaseFirestore.instance.collection('bookings').where('cycleId', isEqualTo: targetId).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kTextPrimary, strokeWidth: 2));
                    if (!snapshot.hasData) return const SizedBox.shrink();

                    final List<QueryDocumentSnapshot> rawDocs = snapshot.data!.docs;
                    final List<QueryDocumentSnapshot> docs = isItem
                        ? rawDocs
                        : rawDocs.where((d) {
                            final data = d.data() as Map<String, dynamic>;
                            return data.containsKey('rating') && (data['rating'] as num) > 0;
                          }).toList();

                    if (docs.isEmpty) {
                      return Center(child: Text("No reviews yet.", style: const TextStyle(color: kTextDim)));
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final int rating = isItem ? (data['rating'] ?? 5) : ((data['rating'] as num?)?.toInt() ?? 0);
                        final String text = isItem ? (data['comment'] ?? '') : (data['reviewText'] ?? '');
                        final String userName = data['userName'] ?? 'Student';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(userName, style: const TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                              Row(children: List.generate(5, (i) => Icon(i < rating ? Icons.star_rounded : Icons.star_border_rounded, color: kAccentAmber, size: 14))),
                            ]),
                            if (text.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(text, style: const TextStyle(color: kTextMuted, fontSize: 12)),
                            ],
                          ]),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
