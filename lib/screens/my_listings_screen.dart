import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'add_cycle_screen.dart';
import 'cycle_history_screen.dart';

class MyListingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text("My Listings")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('cycles')
            .where('ownerId', isEqualTo: user?.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Error loading listings: ${snapshot.error}"));
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
             return Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(Icons.directions_bike, size: 60, color: Colors.grey),
                   SizedBox(height: 10),
                   Text("You haven't listed any cycles yet.", style: TextStyle(color: Colors.grey)),
                   SizedBox(height: 20),
                   ElevatedButton(
                     onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddCycleScreen())),
                     child: Text("LIST NOW", style: TextStyle(color: Colors.black)),
                     style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
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
              bool isAvailable = data['isAvailable'] ?? true;

              return Card(
                color: Color(0xFF1E1E1E),
                margin: EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    // Header Image & Title
                    ListTile(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => CycleHistoryScreen(cycleId: cycleId, cycleData: data)));
                      },
                      contentPadding: EdgeInsets.all(12),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildImage(
                          data['imageUrl'] ?? "", 
                          width: 60, height: 60,
                        ),
                      ),
                      title: Text(
                        "${data['modelName']} - ${data['gearType'] ?? 'Single Geared'}", 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                      ),
                      subtitle: Text("₹${data['basePrice']} / 2hrs • ${data['location']}"),
                      trailing: Switch(
                         value: isAvailable,
                         activeColor: Colors.green,
                         onChanged: (val) {
                           FirebaseFirestore.instance.collection('cycles').doc(cycleId).update({'isAvailable': val});
                         },
                      ),
                    ),
                    Divider(color: Colors.white12),
                    // Action Buttons
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            icon: Icon(Icons.comment, color: Colors.amber),
                            label: Text("REVIEWS", style: TextStyle(color: Colors.amber)),
                            onPressed: () => _showReviewsBottomSheet(context, cycleId),
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
                            onPressed: () => _confirmDelete(context, cycleId),
                          ),
                        ],
                      ),
                    ),
                    if (!isAvailable)
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
      ),
    );
  }

  void _confirmDelete(BuildContext context, String cycleId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text("Delete Listing?"),
        content: Text("This action cannot be undone."),
        actions: [
          TextButton(child: Text("Cancel"), onPressed: () => Navigator.pop(context)),
          TextButton(
            child: Text("Delete", style: TextStyle(color: Colors.red)), 
            onPressed: () {
              FirebaseFirestore.instance.collection('cycles').doc(cycleId).delete();
              Navigator.pop(context);
            }
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
          child: Center(child: Icon(Icons.directions_bike, size: iconSize, color: Colors.white24)),
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
             child: Center(child: Icon(Icons.directions_bike, size: iconSize, color: Colors.white24)),
          ),
        );
     }

     try {
       // Base64
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

  void _showReviewsBottomSheet(BuildContext context, String cycleId) {
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
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('cycleId', isEqualTo: cycleId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
                    if (snapshot.hasError) return Text("Error: ${snapshot.error}", style: TextStyle(color: Colors.red));
                    
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
