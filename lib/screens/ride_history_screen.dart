import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'ride_details_screen.dart';

class RideHistoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text("Your Rides & Rentals"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('userId', isEqualTo: user?.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: TextStyle(color: Colors.white)));

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("No rides or item rentals yet.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          var docs = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var booking = docs[index].data() as Map<String, dynamic>;
              var itemData = booking['itemData'] as Map<String, dynamic>?;
              var cycleData = booking['cycleData'] as Map<String, dynamic>?;

              String title = "Rental Session";
              if (itemData != null && itemData['itemName'] != null) {
                title = "Item: ${itemData['itemName']}";
              } else if (cycleData != null && cycleData['modelName'] != null) {
                title = "Cycle: ${cycleData['modelName']}";
              } else if (booking.containsKey('itemId')) {
                title = "Item Rental";
              } else {
                title = "Cycle Ride";
              }

              String status = booking['status'] ?? 'Unknown';
              DateTime? date;
              if (booking['createdAt'] != null) {
                date = (booking['createdAt'] as Timestamp).toDate();
              }

              double cost = (booking['finalCost'] ?? booking['basePrice'] ?? 0).toDouble();
              int rating = (booking['rating'] ?? 0).toInt();

              return Card(
                color: Color(0xFF1E1E1E),
                margin: EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailsScreen(booking: booking, bookingId: docs[index].id)));
                  },
                  leading: CircleAvatar(
                    backgroundColor: Colors.white10,
                    child: Icon(_getStatusIcon(status, isItem: booking.containsKey('itemId')), color: _getStatusColor(status)),
                  ),
                  title: Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 4),
                      Text(
                        date != null ? DateFormat('MMM dd, yyyy • hh:mm a').format(date) : "Unknown Date",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Status: ${status.toUpperCase()}",
                        style: TextStyle(color: _getStatusColor(status), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      if (status == 'completed') ...[
                        Text("Cost: ₹${cost.toStringAsFixed(0)}", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        if (rating > 0)
                          Row(
                            children: List.generate(
                              5,
                              (i) => Icon(
                                i < rating ? Icons.star : Icons.star_border,
                                size: 12,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                      ] else if (status == 'cancelled') ...[
                        Text(
                          "Fee: ₹${(booking['cancellationFee'] ?? booking['finalCost'] ?? 0).toString()}",
                          style: TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ]
                    ],
                  ),
                  trailing: status == 'completed'
                      ? Icon(Icons.check_circle, color: Colors.green)
                      : (status == 'cancelled' ? Icon(Icons.cancel, color: Colors.red) : Icon(Icons.incomplete_circle, color: Colors.amber)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getStatusIcon(String status, {required bool isItem}) {
    if (status == 'completed') return Icons.flag;
    if (status == 'started') return isItem ? Icons.inventory_2 : Icons.pedal_bike;
    if (status == 'booked') return Icons.bookmark;
    if (status == 'end_requested') return Icons.timer;
    if (status == 'cancelled') return Icons.cancel;
    return Icons.help;
  }

  Color _getStatusColor(String status) {
    if (status == 'completed') return Colors.green;
    if (status == 'started') return Colors.blue;
    if (status == 'booked') return Colors.orange;
    if (status == 'end_requested') return Colors.amber;
    if (status == 'cancelled') return Colors.red;
    return Colors.grey;
  }
}
