import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'add_cycle_screen.dart';
import 'add_item_screen.dart';
import 'add_sale_item_screen.dart';
import 'cycle_history_screen.dart';

class MyListingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: Color(0xFF1E1E1E),
          title: Text("My Listings"),
          bottom: TabBar(
            indicatorColor: Colors.indigoAccent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.pedal_bike), text: "Cycles"),
              Tab(icon: Icon(Icons.inventory_2_outlined), text: "Items"),
              Tab(icon: Icon(Icons.sell_outlined), text: "Sales"),
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
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text("Error loading cycles: ${snapshot.error}", style: TextStyle(color: Colors.white)));

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pedal_bike, size: 60, color: Colors.grey),
                SizedBox(height: 10),
                Text("You haven't listed any cycles yet.", style: TextStyle(color: Colors.grey)),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddCycleScreen())),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  child: Text("LIST A CYCLE NOW", style: TextStyle(color: Colors.black)),
                )
              ],
            ),
          );
        }

        var docs = snapshot.data!.docs;

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String cycleId = docs[index].id;
            bool ownerDisabled = data['ownerDisabled'] ?? false;

            return Card(
              color: Color(0xFF1E1E1E),
              margin: EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => CycleHistoryScreen(cycleId: cycleId, cycleData: data)));
                    },
                    contentPadding: EdgeInsets.all(12),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildImage(data['imageUrl'] ?? "", width: 60, height: 60),
                    ),
                    title: Text(
                      "${data['modelName']} - ${data['gearType'] ?? 'Single Geared'}",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                    ),
                    subtitle: Text("₹${data['basePrice']} / 2hrs • ${data['location']}", style: TextStyle(color: Colors.grey)),
                    trailing: Switch(
                      value: !ownerDisabled,
                      activeColor: Colors.green,
                      onChanged: (val) {
                        FirebaseFirestore.instance.collection('cycles').doc(cycleId).update({'ownerDisabled': !val});
                      },
                    ),
                  ),
                  Divider(color: Colors.white12),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          icon: Icon(Icons.comment, color: Colors.amber),
                          label: Text("REVIEWS", style: TextStyle(color: Colors.amber)),
                          onPressed: () => _showReviewsBottomSheet(context, cycleId, isItem: false),
                        ),
                        TextButton.icon(
                          icon: Icon(Icons.edit, color: Colors.blue),
                          label: Text("EDIT", style: TextStyle(color: Colors.blue)),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => AddCycleScreen(cycleData: data, cycleId: cycleId)));
                          },
                        ),
                        TextButton.icon(
                          icon: Icon(Icons.delete, color: Colors.red),
                          label: Text("DELETE", style: TextStyle(color: Colors.red)),
                          onPressed: () => _confirmDelete(context, cycleId, collection: 'cycles'),
                        ),
                      ],
                    ),
                  ),
                  if (ownerDisabled)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(4),
                      color: Colors.amber.withOpacity(0.2),
                      child: Text("Currently Delisted (Hidden from Home)", textAlign: TextAlign.center, style: TextStyle(color: Colors.amber, fontSize: 10)),
                    )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildItemsTab(BuildContext context, User? user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('items')
          .where('ownerId', isEqualTo: user?.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
        if (snapshot.hasError) return Center(child: Text("Error loading items: ${snapshot.error}", style: TextStyle(color: Colors.white)));

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey),
                SizedBox(height: 10),
                Text("You haven't listed any items yet.", style: TextStyle(color: Colors.grey)),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddItemScreen())),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
                  child: Text("LIST AN ITEM NOW", style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          );
        }

        var docs = snapshot.data!.docs;

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String itemId = docs[index].id;
            bool ownerDisabled = data['ownerDisabled'] ?? false;
            String itemName = data['itemName'] ?? 'Item';
            String itemType = data['itemType'] ?? 'General';
            String location = data['location'] ?? 'Campus';

            return Card(
              color: Color(0xFF1E1E1E),
              margin: EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.all(12),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildImage(data['imageUrl'] ?? "", width: 60, height: 60),
                    ),
                    title: Text(
                      "$itemName - $itemType",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                    ),
                    subtitle: Text("₹${data['basePrice']} / 2hrs • Collect: $location Bhavan", style: TextStyle(color: Colors.grey)),
                    trailing: Switch(
                      value: !ownerDisabled,
                      activeColor: Colors.green,
                      onChanged: (val) {
                        FirebaseFirestore.instance.collection('items').doc(itemId).update({'ownerDisabled': !val});
                      },
                    ),
                  ),
                  Divider(color: Colors.white12),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          icon: Icon(Icons.comment, color: Colors.amber),
                          label: Text("REVIEWS", style: TextStyle(color: Colors.amber)),
                          onPressed: () => _showReviewsBottomSheet(context, itemId, isItem: true),
                        ),
                        TextButton.icon(
                          icon: Icon(Icons.edit, color: Colors.blue),
                          label: Text("EDIT", style: TextStyle(color: Colors.blue)),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => AddItemScreen(itemData: data, itemId: itemId)));
                          },
                        ),
                        TextButton.icon(
                          icon: Icon(Icons.delete, color: Colors.red),
                          label: Text("DELETE", style: TextStyle(color: Colors.red)),
                          onPressed: () => _confirmDelete(context, itemId, collection: 'items'),
                        ),
                      ],
                    ),
                  ),
                  if (ownerDisabled)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(4),
                      color: Colors.amber.withOpacity(0.2),
                      child: Text("Currently Delisted (Hidden from Feed)", textAlign: TextAlign.center, style: TextStyle(color: Colors.amber, fontSize: 10)),
                    )
                ],
              ),
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
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: Colors.orangeAccent));
        if (snapshot.hasError) return Center(child: Text("Error loading sales: ${snapshot.error}", style: TextStyle(color: Colors.white)));

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sell_outlined, size: 60, color: Colors.grey),
                SizedBox(height: 10),
                Text("You haven't listed any items for sale.", style: TextStyle(color: Colors.grey)),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddSaleItemScreen())),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                  child: Text("SELL AN ITEM NOW", style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          );
        }

        var docs = snapshot.data!.docs;

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String itemId = docs[index].id;
            bool ownerDisabled = data['ownerDisabled'] ?? false;
            bool isSold = data['isSold'] ?? false;
            String itemName = data['itemName'] ?? 'Item';
            String itemType = data['itemType'] ?? 'General';
            int price = data['price'] ?? 0;

            return Card(
              color: Color(0xFF1E1E1E),
              margin: EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.all(12),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildImage(data['imageUrl'] ?? "", width: 60, height: 60),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "$itemName - $itemType",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                          ),
                        ),
                        if (isSold)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                            child: Text("SOLD", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                      ],
                    ),
                    subtitle: Text("₹$price • Cond: ${data['condition'] ?? 'Good'}", style: TextStyle(color: Colors.grey)),
                    trailing: Switch(
                      value: !ownerDisabled,
                      activeColor: Colors.green,
                      onChanged: (val) {
                        FirebaseFirestore.instance.collection('sale_items').doc(itemId).update({'ownerDisabled': !val});
                      },
                    ),
                  ),
                  Divider(color: Colors.white12),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          icon: Icon(isSold ? Icons.undo : Icons.check_circle, color: isSold ? Colors.grey : Colors.green),
                          label: Text(isSold ? "AVAILABLE" : "MARK SOLD", style: TextStyle(color: isSold ? Colors.grey : Colors.green)),
                          onPressed: () {
                            FirebaseFirestore.instance.collection('sale_items').doc(itemId).update({'isSold': !isSold});
                          },
                        ),
                        TextButton.icon(
                          icon: Icon(Icons.edit, color: Colors.blue),
                          label: Text("EDIT", style: TextStyle(color: Colors.blue)),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => AddSaleItemScreen(itemData: data, itemId: itemId)));
                          },
                        ),
                        TextButton.icon(
                          icon: Icon(Icons.delete, color: Colors.red),
                          label: Text("DELETE", style: TextStyle(color: Colors.red)),
                          onPressed: () => _confirmDelete(context, itemId, collection: 'sale_items'),
                        ),
                      ],
                    ),
                  ),
                  if (ownerDisabled)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(4),
                      color: Colors.amber.withOpacity(0.2),
                      child: Text("Currently Delisted (Hidden from Feed)", textAlign: TextAlign.center, style: TextStyle(color: Colors.amber, fontSize: 10)),
                    )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String docId, {required String collection}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text("Delete Listing?", style: TextStyle(color: Colors.white)),
        content: Text("This action cannot be undone.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(child: Text("Cancel", style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.pop(context)),
          TextButton(
            child: Text("Delete", style: TextStyle(color: Colors.red)),
            onPressed: () {
              FirebaseFirestore.instance.collection(collection).doc(docId).delete();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String? imageUrl, {double? width, double? height, double iconSize = 50}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: width, height: height,
        color: Colors.grey[850],
        child: Center(child: Icon(Icons.inventory_2, size: iconSize, color: Colors.white24)),
      );
    }

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: width, height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: width, height: height,
          color: Colors.grey[850],
          child: Center(child: Icon(Icons.inventory_2, size: iconSize, color: Colors.white24)),
        ),
      );
    }

    try {
      return Image.memory(
        base64Decode(imageUrl),
        width: width, height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: width, height: height,
          color: Colors.grey[850],
          child: Center(child: Icon(Icons.broken_image, size: iconSize, color: Colors.white24)),
        ),
      );
    } catch (e) {
      return Container(
        width: width, height: height,
        color: Colors.grey[850],
        child: Center(child: Icon(Icons.error, size: iconSize, color: Colors.white24)),
      );
    }
  }

  void _showReviewsBottomSheet(BuildContext context, String targetId, {required bool isItem}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Reviews", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: isItem
                      ? FirebaseFirestore.instance.collection('items').doc(targetId).collection('reviews').orderBy('createdAt', descending: true).snapshots()
                      : FirebaseFirestore.instance.collection('bookings').where('cycleId', isEqualTo: targetId).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
                    if (snapshot.hasError) return Text("Error: ${snapshot.error}", style: TextStyle(color: Colors.red));

                    if (!isItem) {
                      var docs = snapshot.data!.docs.where((d) {
                        var data = d.data() as Map<String, dynamic>;
                        return data.containsKey('rating') && (data['rating'] as num) > 0;
                      }).toList();

                      if (docs.isEmpty) return Center(child: Text("No reviews yet.", style: TextStyle(color: Colors.grey)));

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var data = docs[index].data() as Map<String, dynamic>;
                          double rating = (data['rating'] ?? 0.0).toDouble();
                          String text = data['reviewText'] ?? "";

                          return Container(
                            margin: EdgeInsets.only(bottom: 10),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.star, color: Colors.amber, size: 16),
                                    Text(" $rating", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                if (text.isNotEmpty) ...[
                                  SizedBox(height: 5),
                                  Text(text, style: TextStyle(color: Colors.white70)),
                                ]
                              ],
                            ),
                          );
                        },
                      );
                    } else {
                      var docs = snapshot.data!.docs;
                      if (docs.isEmpty) return Center(child: Text("No reviews yet.", style: TextStyle(color: Colors.grey)));

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var data = docs[index].data() as Map<String, dynamic>;
                          int rating = data['rating'] ?? 5;
                          String text = data['comment'] ?? "";
                          String userName = data['userName'] ?? "Student";

                          return Container(
                            margin: EdgeInsets.only(bottom: 10),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(userName, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    Row(
                                      children: List.generate(5, (i) {
                                        return Icon(
                                          i < rating ? Icons.star : Icons.star_border,
                                          color: Colors.amber,
                                          size: 14,
                                        );
                                      }),
                                    )
                                  ],
                                ),
                                if (text.isNotEmpty) ...[
                                  SizedBox(height: 5),
                                  Text(text, style: TextStyle(color: Colors.white70)),
                                ]
                              ],
                            ),
                          );
                        },
                      );
                    }
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
