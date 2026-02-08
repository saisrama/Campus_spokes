import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'ride_details_screen.dart';

class ReceivedBookingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text("Received Bookings")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('ownerId', isEqualTo: user?.uid)
            .where('status', whereIn: ['booked', 'started', 'payment_pending', 'cancelled'])
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.bookmark_border, size: 60, color: Colors.grey),
                   SizedBox(height: 10),
                   Text("No upcoming or current bookings.", style: TextStyle(color: Colors.grey)),
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
              String bookingId = docs[index].id;
              String status = booking['status'] ?? 'unknown';
              String cycleName = booking['cycleData']?['modelName'] ?? "Cycle";
              String renterId = booking['userId'];
              
              DateTime? createdAt;
              if (booking['createdAt'] != null) {
                createdAt = (booking['createdAt'] as Timestamp).toDate();
              }

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(renterId).get(),
                builder: (context, userSnapshot) {
                  String renterName = "Loading...";
                  String renterPhone = "";
                  
                  if (userSnapshot.connectionState == ConnectionState.done) {
                    if (userSnapshot.hasData && userSnapshot.data!.exists) {
                      var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                      renterName = userData['displayName'] ?? "User";
                      renterPhone = userData['phoneNumber'] ?? "";
                    } else {
                      // Fallback: Check if booking has snapshot data (future proofing)
                      renterName = booking['renterName'] ?? "Unknown User";
                      renterPhone = booking['renterPhone'] ?? "";
                    }
                  }

                  return Card(
                    color: Color(0xFF1E1E1E),
                    margin: EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailsScreen(booking: booking, bookingId: bookingId)));
                      },
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(status).withOpacity(0.1),
                        child: Icon(_getStatusIcon(status), color: _getStatusColor(status)),
                      ),
                      title: Text(cycleName, style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Renter: $renterName", style: TextStyle(color: Colors.white70)),
                          if (renterPhone.isNotEmpty)
                             Text("Phone: $renterPhone", style: TextStyle(color: Colors.white54, fontSize: 11)),
                          
                          SizedBox(height: 4),
                          Text("Status: ${status.toUpperCase()}", style: TextStyle(
                            color: _getStatusColor(status), fontSize: 12, fontWeight: FontWeight.bold
                          )),
                          
                          if (status == 'cancelled')
                             Text(
                               "Cancellation Fee: ₹${(booking['cancellationFee'] ?? booking['finalCost'] ?? 0).toString()}", 
                               style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)
                             ),

                          if (createdAt != null)
                            Text("Booked on: ${DateFormat('MMM dd, hh:mm a').format(createdAt)}", style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    if (status == 'completed') return Icons.check_circle;
    if (status == 'started') return Icons.pedal_bike;
    if (status == 'booked') return Icons.bookmark;
    if (status == 'payment_pending') return Icons.payment;
    if (status == 'cancelled') return Icons.cancel;
    return Icons.help;
  }

  Color _getStatusColor(String status) {
    if (status == 'completed') return Colors.green;
    if (status == 'started') return Colors.blue;
    if (status == 'booked') return Colors.orange;
    if (status == 'payment_pending') return Colors.amber;
    if (status == 'cancelled') return Colors.red;
    return Colors.grey;
  }
}
